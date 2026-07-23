# Self-host Qwen3-8B với vLLM (Vast.ai instance)

Phục vụ model `Qwen/Qwen3-8B` qua vLLM, expose ra internet dưới dạng
OpenAI-compatible API (`/v1/chat/completions`), chạy như một supervisor
service (tự khởi động lại khi crash) đằng sau Caddy reverse proxy (auth token).

Đã test trên: RTX 4090 (48GB VRAM), CUDA driver 13.0, Ubuntu (Vast.ai base image).

## 1. Cài vLLM

```bash
source /venv/main/bin/activate
uv pip install --native-tls --upgrade vllm
```

> `--native-tls` là bắt buộc trên môi trường mạng Vast.ai này — `uv` mặc định
> dùng root cert bundle riêng (rustls/webpki) và bị lỗi
> `invalid peer certificate: UnknownIssuer` khi tải từ PyPI. Cờ này ép `uv`
> dùng cert store của hệ điều hành (`/etc/ssl/certs/ca-certificates.crt`),
> nơi `curl` vẫn tải thành công bình thường.

## 2. Tắt HuggingFace Xet download backend

```bash
echo 'HF_HUB_DISABLE_XET=1' >> ${WORKSPACE}/.env
```

> Backend tải mới của HF Hub (`hf_xet`) bị lỗi 404 khi gọi tới một CDN node
> lạ trên mạng này (`ConnectionError: ... xet-read-token ... 404 Not Found`).
> Set biến này để HF Hub tải bằng HTTP thường thay vì Xet.

## 3. Copy file vào đúng vị trí

```bash
cp vllm-qwen.sh /opt/supervisor-scripts/vllm-qwen.sh
chmod +x /opt/supervisor-scripts/vllm-qwen.sh

cp vllm-qwen.supervisor.conf /etc/supervisor/conf.d/vllm-qwen.conf

supervisorctl reread
supervisorctl update
```

`vllm-qwen.sh` chạy `vllm serve Qwen/Qwen3-8B` trên `127.0.0.1:18000`
(chỉ nội bộ — Caddy sẽ expose ra ngoài ở bước sau).

## 4. Expose ra internet qua Caddy (auth token)

Thêm nội dung `portal.yaml.snippet` vào `/etc/portal.yaml` (dưới key
`applications:`), chọn một external port còn trống:

```bash
vast-capabilities | jq '.instance.open_ports[] | select(.in_use==false)'
```

Rồi:

```bash
supervisorctl restart caddy
```

Model sẽ dùng khoảng 2-3 phút để tải weights (~16GB) lần đầu và nạp vào GPU.
Theo dõi log:

```bash
tail -f /var/log/portal/vllm-qwen.log
```

Kiểm tra sẵn sàng:

```bash
curl http://127.0.0.1:18000/v1/models
```

## 5. Gọi API từ bên ngoài

Xem `qwen_client_example.py`. Cần base URL dạng
`http://<PUBLIC_IPADDR>:<VAST_TCP_PORT_10100>/v1` và token
(`$OPEN_BUTTON_TOKEN` hoặc `$WEB_PASSWORD` trên instance, truyền qua header
`Authorization: Bearer <token>`).

### Lưu ý: Qwen3 "thinking mode"

Qwen3 mặc định suy nghĩ trong thẻ `<think>...</think>` trước khi trả lời
thật — tốn nhiều token hơn. Tắt bằng:

```json
{"chat_template_kwargs": {"enable_thinking": false}}
```

(truyền qua `extra_body` nếu dùng OpenAI Python SDK).

## Cấu hình vLLM hiện tại

| Tham số | Giá trị |
|---|---|
| Model | `Qwen/Qwen3-8B` |
| Served name | `qwen3-8b` |
| Port nội bộ | `18000` |
| `--max-model-len` | `16384` |
| `--gpu-memory-utilization` | `0.90` |

Điều chỉnh trực tiếp trong `vllm-qwen.sh` rồi `supervisorctl restart vllm-qwen`.
