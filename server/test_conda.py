import sys
import importlib

def verify_environment():
    print("--- CONDA ENVIRONMENT VERIFICATION ---")
    
    # List of critical packages for the project
    required_packages = [
        "torch", 
        "transformers", 
        "diffusers", 
        "accelerate", 
        "bark", 
        "fastapi",
        "scipy",
        "uvicorn"
    ]
    
    all_passed = True
    
    for package in required_packages:
        try:
            importlib.import_module(package)
            print(f"[PASS] {package:15} is available")
        except ImportError:
            # Special case for bark if it was installed from git and might need different import
            if package == "bark":
                try:
                    import bark
                    print(f"[PASS] bark            is available")
                    continue
                except ImportError:
                    pass
            print(f"[FAIL] {package:15} is NOT installed")
            all_passed = False
    
    print("-" * 40)
    
    if not all_passed:
        print("RESULT: FAILURE - One or more required packages are missing.")
        sys.exit(1)
        
    # GPU Verification logic
    import torch
    print(f"Python Version:  {sys.version.split()[0]}")
    print(f"PyTorch Version: {torch.__version__}")
    
    cuda_status = torch.cuda.is_available()
    print(f"CUDA Available:  {cuda_status}")
    
    if cuda_status:
        print(f"GPU Device:      {torch.cuda.get_device_name(0)}")
        print(f"CUDA Version:    {torch.version.cuda}")
    else:
        print("[!] No GPU detected. Skip this if you are not on the Vast.ai server.")

    print("-" * 40)
    print("RESULT: SUCCESS - Environment is correctly configured.")

if __name__ == "__main__":
    verify_environment()
