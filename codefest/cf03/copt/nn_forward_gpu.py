import torch
import torch.nn as nn
import sys

# Step 1: Detect GPU and print device name
if torch.cuda.is_available():
    device = torch.device("cuda")
    print(f"CUDA GPU detected: {torch.cuda.get_device_name(0)}")
else:
    print("No CUDA GPU found. Exiting.")
    sys.exit(1)

# Step 2: Define the network
# Architecture: Linear(4 -> 5) -> ReLU -> Linear(5 -> 1)
model = nn.Sequential(
    nn.Linear(4, 5),
    nn.ReLU(),
    nn.Linear(5, 1)
)
model.to(device)
print(f"\nModel architecture:\n{model}")
print(f"Model is on: {next(model.parameters()).device}")

# Step 3: Generate random input, run forward pass, verify output
x = torch.randn(16, 4).to(device)
print(f"\nInput shape:  {x.shape}")
print(f"Input device: {x.device}")

output = model(x)
print(f"\nOutput shape:  {output.shape}")
print(f"Output device: {output.device}")
print(f"\nOutput tensor:\n{output}")
