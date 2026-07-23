"""
Ví dụ gọi Qwen3-8B đang chạy trên vLLM, dùng OpenAI SDK.
Cài trước: pip install openai
"""
import os
from openai import OpenAI

# Gọi từ BÊN NGOÀI instance (qua internet, có auth token):
client = OpenAI(
    base_url="http://23.158.136.85:30104/v1",
    api_key=os.environ.get("VAST_TOKEN", "PASTE_YOUR_OPEN_BUTTON_TOKEN_HERE"),
)

# Nếu gọi từ BÊN TRONG instance (localhost, không cần token), dùng:
# client = OpenAI(base_url="http://127.0.0.1:18000/v1", api_key="not-needed")

# Lưu ý: Qwen3 mặc định bật "thinking mode" — model suy nghĩ trong thẻ
# <think>...</think> trước khi trả lời, nên tốn nhiều token hơn bình thường.
# max_tokens cần đủ lớn để chứa cả phần suy nghĩ + câu trả lời thật.

response = client.chat.completions.create(
    model="qwen3-8b",
    messages=[
        {"role": "user", "content": "Xin chào! Bạn là ai?"},
    ],
    max_tokens=1024,
    temperature=0.7,
    # Tắt thinking mode để trả lời nhanh, ngắn gọn hơn (Qwen3 hỗ trợ qua chat template):
    extra_body={"chat_template_kwargs": {"enable_thinking": False}},
)

print(response.choices[0].message.content)
