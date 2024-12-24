import torch

# Check if GPU is available
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

# Define sample data
X = torch.tensor([[1.0], [2.0], [3.0], [4.0]], dtype=torch.float32).to(device)
y = torch.tensor([2.0, 4.0, 5.0, 6.0], dtype=torch.float32).to(device)

# Define model
class LinearRegression(torch.nn.Module):
  def __init__(self):
    super(LinearRegression, self).__init__()
    self.linear = torch.nn.Linear(1, 1)  # Input: 1 feature, Output: 1 value

  def forward(self, x):
    return self.linear(x)

# Move model to the chosen device
model = LinearRegression().to(device)

# Define loss function and optimizer
loss_fn = torch.nn.MSELoss()
optimizer = torch.optim.SGD(model.parameters(), lr=0.01)

# Training loop
n_epochs = 1000000
for epoch in range(n_epochs):
  # Forward pass
  y_pred = model(X)
  loss = loss_fn(y_pred, y)

  # Backward pass and optimize
  optimizer.zero_grad()
  loss.backward()
  optimizer.step()

# Print final prediction
print(f"Predicted value for input {X[0]} : {model(X[0].unsqueeze(0)).item()}")

