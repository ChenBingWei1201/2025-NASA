#!/usr/bin/env python3

from PIL import Image
import os

def extract_hidden_message(image_path):
    # Open the image
    img = Image.open(image_path)
    
    # Get pixels' values
    pixels = list(img.getdata())
    
    extracted_data = ""
    i = 0
    
    while True:
        # Check if we have enough pixels for the next character
        if i * 3 + 2 >= len(pixels):
            break
            
        # Get RGB values from 3 consecutive pixels
        colors = list(pixels[i * 3]) + list(pixels[i * 3 + 1]) + list(pixels[i * 3 + 2])

        # Extract the LSBs to reconstruct the binary
        binary_str = ""
        for j in range(8):  # 8 bits per character
            lsb = colors[j] & 1  # Get the least significant bit
            binary_str += str(lsb)
        
        # Convert binary to character
        char_code = int(binary_str, 2)
        
        # If we encounter a null byte, we've reached the end
        if char_code == 0:
            break
            
        char = chr(char_code)
        extracted_data += char
        
        # Stop if we find the flag ending
        if extracted_data.endswith("}"):
            break
            
        i += 1
    
    return extracted_data

if __name__ == "__main__":
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    # Extract the flag
    image_path = os.path.join(script_dir, "secret_mygo.png")
    hidden_message = extract_hidden_message(image_path)
    print(f"flag: {hidden_message}")
