#!/usr/bin/env python3
"""
KVM Manager Service - Python Backend
Controls MLEEDA KVM1001A hardware switch via RS232 serial communication.

Author: KVM Manager Team
Version: 1.0.0
"""

import asyncio
import json
import logging
import os
import time
from pathlib import Path
from typing import Dict, List, Optional, Union

import psutil
import serial
import serial.tools.list_ports
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

# Load environment variables from .env file
try:
    from dotenv import load_dotenv
    # Load .env from parent directory
    env_path = Path(__file__).parent.parent / '.env'
    load_dotenv(env_path)
    print(f"Loaded environment variables from {env_path}")
except ImportError:
    print("python-dotenv not installed, using system environment variables only")
except Exception as e:
    print(f"Error loading .env file: {e}")

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="KVM Manager Service",
    description="Python backend for controlling MLEEDA KVM1001A hardware switch",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Constants for MLEEDA KVM1001A
PORT_COMMANDS = {
    1: "X1,1$", 2: "X2,1$", 3: "X3,1$", 4: "X4,1$", 5: "X5,1$",
    6: "X6,1$", 7: "X7,1$", 8: "X8,1$", 9: "X9,1$", 10: "XA,1$"
}

AVAILABLE_PORTS = list(range(1, 11))  # Ports 1-10

SERIAL_CONFIG = {
    'baudrate': 115200,
    'bytesize': serial.EIGHTBITS,
    'parity': serial.PARITY_NONE,
    'stopbits': serial.STOPBITS_ONE,
    'timeout': 1.0,
    'write_timeout': 1.0
}

# Response Models
class SerialPortInfo(BaseModel):
    device: str
    description: str

class SerialPortsResponse(BaseModel):
    serial_ports: List[SerialPortInfo]
    default_port: Optional[str] = None

class PortsResponse(BaseModel):
    available_ports: List[int]
    commands: Dict[str, str]
    port_names: Dict[int, str]

class SwitchResponse(BaseModel):
    success: bool
    port: int
    command: str
    response: str
    error: Optional[str] = None

class HealthResponse(BaseModel):
    status: str
    service: str
    version: str
    python_version: str
    serial_ports_count: int

# Utility Functions
def get_serial_ports() -> List[SerialPortInfo]:
    """Get all available serial ports on the system."""
    try:
        ports = serial.tools.list_ports.comports()
        serial_ports = []
        
        for port in ports:
            # Filter for USB serial devices and ttyUSB devices
            if any(keyword in port.description.lower() for keyword in ['usb', 'serial', 'ch340', 'ftdi', 'cp210']):
                serial_ports.append(SerialPortInfo(
                    device=port.device,
                    description=port.description or f"Serial Port {port.device}"
                ))
        
        # Sort by device name
        serial_ports.sort(key=lambda x: x.device)
        
        logger.info(f"Found {len(serial_ports)} serial ports")
        return serial_ports
        
    except Exception as e:
        logger.error(f"Error getting serial ports: {e}")
        return []

def get_default_serial_port() -> Optional[str]:
    """Get the default serial port, preferring ttyUSB0."""
    serial_ports = get_serial_ports()
    
    if not serial_ports:
        return None
    
    # Prefer /dev/ttyUSB0 if available
    for port in serial_ports:
        if "/dev/ttyUSB0" in port.device:
            return port.device
    
    # Fall back to first USB serial port
    for port in serial_ports:
        if "ttyUSB" in port.device or "USB" in port.description:
            return port.device
    
    # Return first available port
    return serial_ports[0].device

def get_port_names_from_env() -> Dict[int, str]:
    """Get friendly port names from environment variables."""
    import os
    
    port_names = {}
    for port in AVAILABLE_PORTS:
        env_key = f"KVM_PORT_{port}_NAME"
        env_value = os.getenv(env_key)
        if env_value:
            port_names[port] = env_value
        else:
            port_names[port] = f"Server {port}"  # Default fallback
    
    logger.debug(f"Port names from environment: {port_names}")
    return port_names

def validate_port_number(port: int) -> bool:
    """Validate that port number is in valid range."""
    return 1 <= port <= 10

def switch_kvm_port(serial_port: str, port_num: int) -> SwitchResponse:
    """
    Switch KVM to specified port using MLEEDA KVM1001A protocol.
    
    Args:
        serial_port: Serial device path (e.g., '/dev/ttyUSB0')
        port_num: Port number (1-10)
    
    Returns:
        SwitchResponse with operation result
    """
    if not validate_port_number(port_num):
        return SwitchResponse(
            success=False,
            port=port_num,
            command="",
            response="",
            error=f"Invalid port number: {port_num}. Must be 1-10."
        )
    
    command = PORT_COMMANDS[port_num]
    
    try:
        logger.info(f"Switching to port {port_num} on {serial_port}")
        
        # Open serial connection
        with serial.Serial(
            port=serial_port,
            **SERIAL_CONFIG
        ) as ser:
            # Clear input/output buffers
            ser.reset_input_buffer()
            ser.reset_output_buffer()
            
            # Send command
            ser.write(command.encode('ascii'))
            ser.flush()
            
            # Wait for hardware response (MLEEDA timing requirement)
            time.sleep(0.5)
            
            # Read response
            response_bytes = ser.read(ser.in_waiting or 1024)
            response = response_bytes.decode('ascii', errors='ignore').strip()
            
            logger.info(f"Successfully switched to port {port_num}")
            logger.debug(f"Command: {command}, Response: {response}")
            
            return SwitchResponse(
                success=True,
                port=port_num,
                command=command,
                response=response
            )
            
    except serial.SerialException as e:
        error_msg = f"Serial communication failed: {e}"
        logger.error(error_msg)
        return SwitchResponse(
            success=False,
            port=port_num,
            command=command,
            response="",
            error=error_msg
        )
        
    except PermissionError as e:
        error_msg = f"Access denied to serial port {serial_port}: {e}"
        logger.error(error_msg)
        return SwitchResponse(
            success=False,
            port=port_num,
            command=command,
            response="",
            error=error_msg
        )
        
    except Exception as e:
        error_msg = f"Unexpected error: {e}"
        logger.error(error_msg)
        return SwitchResponse(
            success=False,
            port=port_num,
            command=command,
            response="",
            error=error_msg
        )

# API Endpoints
@app.get("/", response_class=JSONResponse)
async def root():
    """Root endpoint with service information."""
    return {
        "service": "KVM Manager Service",
        "version": "1.0.0",
        "description": "Python backend for MLEEDA KVM1001A control",
        "endpoints": {
            "health": "/health",
            "serial_ports": "/serial_ports",
            "ports": "/ports",
            "switch": "/switch?serial_port={device}&port={1-10}",
            "docs": "/docs"
        }
    }

@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint."""
    import sys
    
    serial_ports = get_serial_ports()
    
    return HealthResponse(
        status="healthy",
        service="KVM Manager Service",
        version="1.0.0",
        python_version=f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}",
        serial_ports_count=len(serial_ports)
    )

@app.get("/serial_ports", response_model=SerialPortsResponse)
async def get_serial_ports_endpoint():
    """Get available serial ports."""
    try:
        serial_ports = get_serial_ports()
        default_port = get_default_serial_port()
        
        return SerialPortsResponse(
            serial_ports=serial_ports,
            default_port=default_port
        )
        
    except Exception as e:
        logger.error(f"Error in get_serial_ports_endpoint: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to get serial ports: {e}")

@app.get("/ports", response_model=PortsResponse)
async def get_ports():
    """Get available KVM ports, their commands, and friendly names."""
    try:
        # Convert port numbers to strings for commands dict
        commands = {str(port): command for port, command in PORT_COMMANDS.items()}
        
        # Get port names from environment variables
        port_names = get_port_names_from_env()
        
        return PortsResponse(
            available_ports=AVAILABLE_PORTS,
            commands=commands,
            port_names=port_names
        )
        
    except Exception as e:
        logger.error(f"Error in get_ports: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to get ports: {e}")

@app.get("/switch", response_model=SwitchResponse)
async def switch_port(
    serial_port: str = Query(..., description="Serial port device path"),
    port: int = Query(..., ge=1, le=10, description="KVM port number (1-10)")
):
    """Switch KVM to specified port."""
    try:
        logger.info(f"Switch request: port={port}, serial_port={serial_port}")
        
        # Validate serial port exists
        if not Path(serial_port).exists():
            raise HTTPException(
                status_code=400, 
                detail=f"Serial port {serial_port} does not exist"
            )
        
        # Execute the switch operation
        result = switch_kvm_port(serial_port, port)
        
        if not result.success:
            # Return error but with 200 status for consistent API behavior
            logger.warning(f"Switch operation failed: {result.error}")
        
        return result
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in switch_port: {e}")
        raise HTTPException(status_code=500, detail=f"Switch operation failed: {e}")

# Additional utility endpoints
@app.get("/test_serial/{serial_port}")
async def test_serial_port(serial_port: str):
    """Test serial port connectivity."""
    try:
        with serial.Serial(serial_port, **SERIAL_CONFIG) as ser:
            return {
                "success": True,
                "message": f"Successfully connected to {serial_port}",
                "port_info": {
                    "name": ser.name,
                    "baudrate": ser.baudrate,
                    "timeout": ser.timeout
                }
            }
    except Exception as e:
        return {
            "success": False,
            "error": f"Failed to connect to {serial_port}: {e}"
        }

def main():
    """Main entry point for the service."""
    import uvicorn
    
    logger.info("Starting KVM Manager Service...")
    logger.info(f"Available serial ports: {[p.device for p in get_serial_ports()]}")
    
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8081,
        reload=False,  # Set to True for development
        log_level="info"
    )

if __name__ == "__main__":
    main()
