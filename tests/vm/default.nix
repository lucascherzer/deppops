{ pkgs, deppopsPackage }:

pkgs.testers.runNixOSTest {
  name = "deppops-vm-test";

  nodes = {
    server = { config, pkgs, ... }: {
      networking.firewall.enable = false;

      systemd.services.deppops = {
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        serviceConfig = {
          ExecStart = "${deppopsPackage}/bin/deppops";
          Restart = "on-failure";
        };
      };
    };

    client = { config, pkgs, ... }: {
      environment.systemPackages = with pkgs; [
        curl
      ];
    };
  };

  testScript = ''
    start_all()

    server.wait_for_unit("deppops.service")
    server.wait_for_open_port(8080)

    # Test hello endpoint
    client.succeed("curl -sf http://server:8080/ | grep -q 'Hello!'")

    # Test liveness endpoint
    client.succeed("curl -sf http://server:8080/health/live | grep -q 'alive'")

    # Test readiness endpoint
    client.succeed("curl -sf http://server:8080/health/ready | grep -q 'ready'")
  '';
}
