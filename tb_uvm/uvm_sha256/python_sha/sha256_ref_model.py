import sys
import hashlib

def main():
    # Make sure we got an argument
    if len(sys.argv) != 2:
        print("ERROR_USAGE")
        sys.exit(1)
    
    hex_input = sys.argv[1]
    
    try:
        # Convert hex string (e.g. "006263") to raw bytes
        data = bytes.fromhex(hex_input)
        
        # Calculate SHA-256 hash
        hash_hex = hashlib.sha256(data).hexdigest()
        
        # Print ONLY the hash so SystemVerilog can read it easily
        print(hash_hex)
    except Exception as e:
        print(f"ERROR_{e}")

if __name__ == "__main__":
    main()
