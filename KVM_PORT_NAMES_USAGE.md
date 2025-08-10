# KVM Port Names Usage Examples

This document shows how to use the KVM port friendly names in your application.

## Environment Variables Available

The following environment variables are automatically available in your containers:

```bash
KVM_PORT_1_NAME=Web-Server
KVM_PORT_2_NAME=Database-Server
KVM_PORT_3_NAME=Application-Server
# ... up to KVM_PORT_16_NAME
```

## Python Backend Usage

```python
import os

# Get friendly name for a port
def get_port_name(port_number):
    """Get the friendly name for a KVM port"""
    env_key = f"KVM_PORT_{port_number}_NAME"
    return os.getenv(env_key, f"Server-{port_number}")

# Example usage in your FastAPI application
@app.get("/kvm/ports")
async def get_kvm_ports():
    """Return list of all KVM ports with their friendly names"""
    ports = []
    max_ports = int(os.getenv("KVM_MAX_PORTS", "16"))

    for port_num in range(1, max_ports + 1):
        ports.append({
            "port": port_num,
            "name": get_port_name(port_num),
            "active": False  # You'll determine this based on KVM status
        })

    return {"ports": ports}

@app.post("/kvm/switch/{port_number}")
async def switch_to_port(port_number: int):
    """Switch to a specific KVM port using friendly name"""
    port_name = get_port_name(port_number)

    # Your KVM switching logic here
    success = await switch_kvm_port(port_number)

    if success:
        return {
            "message": f"Switched to {port_name} (Port {port_number})",
            "port": port_number,
            "name": port_name
        }
    else:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to switch to {port_name}"
        )

# Get port by name
@app.post("/kvm/switch-by-name/{port_name}")
async def switch_by_name(port_name: str):
    """Switch to a port using its friendly name"""
    max_ports = int(os.getenv("KVM_MAX_PORTS", "16"))

    # Find port number by name
    port_number = None
    for port_num in range(1, max_ports + 1):
        if get_port_name(port_num).lower() == port_name.lower():
            port_number = port_num
            break

    if port_number is None:
        raise HTTPException(
            status_code=404,
            detail=f"Port with name '{port_name}' not found"
        )

    # Switch to the port
    return await switch_to_port(port_number)
```

## Node.js Frontend Usage

```javascript
// Get KVM port configuration
const getKvmPorts = () => {
  const ports = [];
  const maxPorts = parseInt(process.env.KVM_MAX_PORTS || "16");

  for (let i = 1; i <= maxPorts; i++) {
    const portName = process.env[`KVM_PORT_${i}_NAME`] || `Server-${i}`;
    ports.push({
      port: i,
      name: portName,
      active: false,
    });
  }

  return ports;
};

// Express route to serve port configuration
app.get("/api/kvm/ports", (req, res) => {
  res.json({
    ports: getKvmPorts(),
  });
});

// Switch by port name
app.post("/api/kvm/switch-by-name", async (req, res) => {
  const { portName } = req.body;
  const ports = getKvmPorts();

  const targetPort = ports.find(
    (p) => p.name.toLowerCase() === portName.toLowerCase()
  );

  if (!targetPort) {
    return res.status(404).json({
      error: `Port with name '${portName}' not found`,
    });
  }

  // Forward to Python backend
  try {
    const response = await fetch(
      `http://localhost:8081/kvm/switch/${targetPort.port}`,
      {
        method: "POST",
      }
    );

    const result = await response.json();
    res.json(result);
  } catch (error) {
    res.status(500).json({
      error: "Failed to switch KVM port",
    });
  }
});
```

## Frontend UI Examples

```html
<!-- HTML for port selection -->
<div class="kvm-port-selector">
  <h3>Select KVM Port</h3>
  <div class="port-grid" id="portGrid">
    <!-- Populated by JavaScript -->
  </div>
</div>

<script>
  // JavaScript to populate port grid
  async function loadKvmPorts() {
    try {
      const response = await fetch("/api/kvm/ports");
      const data = await response.json();

      const portGrid = document.getElementById("portGrid");
      portGrid.innerHTML = "";

      data.ports.forEach((port) => {
        const portButton = document.createElement("button");
        portButton.className = `port-button ${port.active ? "active" : ""}`;
        portButton.innerHTML = `
                <div class="port-number">Port ${port.port}</div>
                <div class="port-name">${port.name}</div>
            `;

        portButton.onclick = () => switchToPort(port.port, port.name);
        portGrid.appendChild(portButton);
      });
    } catch (error) {
      console.error("Failed to load KVM ports:", error);
    }
  }

  async function switchToPort(portNumber, portName) {
    try {
      const response = await fetch(`/api/kvm/switch/${portNumber}`, {
        method: "POST",
      });

      const result = await response.json();

      if (response.ok) {
        showNotification(`Switched to ${portName}`, "success");
        loadKvmPorts(); // Refresh the UI
      } else {
        showNotification(`Failed to switch to ${portName}`, "error");
      }
    } catch (error) {
      showNotification("Connection error", "error");
    }
  }

  // Load ports when page loads
  document.addEventListener("DOMContentLoaded", loadKvmPorts);
</script>
```

## CSS Styling Example

```css
.kvm-port-selector {
  max-width: 800px;
  margin: 20px auto;
  padding: 20px;
}

.port-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 15px;
  margin-top: 20px;
}

.port-button {
  background: #f8f9fa;
  border: 2px solid #dee2e6;
  border-radius: 8px;
  padding: 15px;
  cursor: pointer;
  transition: all 0.3s ease;
  text-align: center;
}

.port-button:hover {
  background: #e9ecef;
  border-color: #007bff;
  transform: translateY(-2px);
}

.port-button.active {
  background: #007bff;
  color: white;
  border-color: #0056b3;
}

.port-number {
  font-size: 14px;
  font-weight: bold;
  color: #6c757d;
}

.port-button.active .port-number {
  color: #ffffff;
}

.port-name {
  font-size: 16px;
  margin-top: 5px;
  font-weight: 500;
}
```

## Configuration Management

### Using the Configuration Script

```bash
# Interactive configuration
./configure-kvm-names.sh

# Quick configuration examples
export KVM_PORT_1_NAME="Production-Web"
export KVM_PORT_2_NAME="Staging-DB"
docker compose up -d
```

### CSV Import/Export

```csv
port_number,device_name
1,Web-Server-Primary
2,Web-Server-Secondary
3,Database-Master
4,Database-Slave
5,Application-Server-1
6,Application-Server-2
7,Load-Balancer
8,Cache-Server
```

### Dynamic Configuration Updates

```bash
# Update environment and restart
echo "KVM_PORT_1_NAME=New-Server-Name" >> .env
docker compose restart kvm-manager
```

This system allows you to:

- 🏷️ **Assign meaningful names** to KVM ports
- 🎯 **Switch by name** instead of just numbers
- 🔄 **Update names** without code changes
- 📊 **Display friendly names** in the UI
- 📂 **Import/Export** configurations
- 🎨 **Use preset** configurations for common setups
