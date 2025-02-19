export INFERENCE_MODEL=meta-llama/Llama-3.1-8B-Instruct
export LLAMA_STACK_PORT=5001

check_status() {
curl --silent --output /dev/null --write-out "%{http_code}" --request POST \
    --url http://localhost:5001/v1/inference/chat-completion \
    --header 'Accept: application/json, text/event-stream' \
    --header 'Content-Type: application/json' \
    --data '{
    "model_id": "'"$INFERENCE_MODEL"'",
    "messages": [
        {
            "role": "user",
            "content": "How do I cook an egg?"
        }
    ],
    "stream": true,
    "sampling_params": {
        "strategy": {
            "type": "greedy"
        },
        "max_tokens": 30,
        "repetition_penalty": 1
    }
}' | grep -q "200"
}

if [ -z "$VLLM_URL" ] || [ -z "$VLLM_API_TOKEN" ]; then
  echo "VLLM_URL and VLLM_API_TOKEN must be set"
  exit 1
fi

if podman ps -a | grep -q remote-vllm; then
  echo "Stopping the server"
  podman stop remote-vllm
  echo "Removing the server"
  podman rm remote-vllm
fi

echo "Starting the server"
podman run -d \
  --name remote-vllm \
  -p $LLAMA_STACK_PORT:$LLAMA_STACK_PORT \
  llamastack/distribution-remote-vllm \
  --port $LLAMA_STACK_PORT \
  --env INFERENCE_MODEL=$INFERENCE_MODEL \
  --env VLLM_URL=$VLLM_URL \
  --env VLLM_API_TOKEN=$VLLM_API_TOKEN

echo "Waiting for the server to be available"
for i in {1..60}; do
  if check_status; then
    echo "Server is ready"
    exit 0
  fi
  sleep 1
done
echo "Server is not ready"
exit 1
