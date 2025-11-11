import paramiko
    
def test_ssh_connection():
    hostname = "localhost"
    port = 22220
    username = "nixos"
    password = "password"

    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    try:
        client.connect(hostname, port=port, username=username, password=password)
        stdin, stdout, stderr = client.exec_command("echo 'Hello, World!'")
        output = stdout.read().decode().strip()
        assert output == "Hello, World!"
    finally:
        client.close()
