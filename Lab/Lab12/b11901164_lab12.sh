#!/bin/bash
uri="http://localhost:11434/api/chat"
model="llama3.2:3b" # Change this to the model name you use.

# Initialize messages array with a system prompt
message='[{"role": "system", "content": "You are a helpful AI assistant that can execute shell commands on Ubuntu. Your job is to translate natural language requests into shell commands, execute them, and explain the results. Only generate valid shell commands that are safe to execute. If a command might be dangerous, warn the user and suggest a safer alternative."}]'

# Define tools for the LLM to use
tools='[{
  "type": "function",
  "function": {
    "name": "execute_command",
    "description": "Run a bash command on the Ubuntu system. Use it to satisfy the requirements from the user.",
    "parameters": {
      "type": "object",
      "properties": {
        "command": {
          "type": "string",
          "description": "The bash command to execute."
        }
      },
      "required": ["command"]
    }
  }
}]'

while true; do
  # Prompt the user for input
  echo -n "Enter your prompt (type 'exit' to quit): "
  read user_input
  
  if [ "$user_input" == "exit" ]; then
    echo "Bye!"
    curl -s -X POST "$uri" -d "{\"model\":\"$model\",\"keep_alive\":0}" > /dev/null
    break
  fi
  
  message=$(echo "$message" | jq '. += [{"role": "user", "content": $input}]' --arg input "$user_input")
  # add the user prompt to messages
  
  endcall=false
  while [ "$endcall" == "false" ]; do # continue until there is no tool calls
    body=$(jq -n --arg model "$model" --argjson messages "$message" --argjson tools "$tools" '{model: $model, messages: $messages, tools: $tools, stream: false}')
    
    response=$(curl -s -X POST "$uri" -d "$body" -H "Content-Type: application/json")
    
    assistant_message=$(echo "$response" | jq .message)
    message=$(echo "$message" | jq '. += [$input]' --argjson input "$assistant_message")
    
    endcall=true
    
    tool_calls=$(echo "$response" | jq -r '.message.tool_calls // []')
    if [ "$tool_calls" != "[]" ]; then
      num_calls=$(echo "$tool_calls" | jq -r 'length')
      for ((i=0; i<num_calls; i++)); do
        # Parse the command to be executed
        command=$(echo "$tool_calls" | jq -r ".[${i}].function.arguments.command")
        echo "Executing command: $command"
        
        # Execute the command and capture its output
        command_return=$(eval "$command" 2>&1)
        
        # Add the command output to the message array
        message=$(echo "$message" | jq '. += [{"role": "tool", "content": $input}]' --arg input "$command_return")
        endcall=false # POST again to return command output
      done
    fi
    
    content=$(echo "$assistant_message" | jq -r '.content // ""') # If message is present, print to the user.
    if [ -n "$content" ]; then
      echo "$content"
    fi
  done
done
