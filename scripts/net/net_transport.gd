class_name NetTransport
extends RefCounted
## How players find and reach each other. The game only ever sees the
## MultiplayerPeer this returns, so a Steam lobby transport (GodotSteam's
## SteamMultiplayerPeer) can replace the direct-IP one without touching gameplay.

## Human-readable name for the lobby screen.
func label() -> String:
	return "Direct IP"


## Start hosting. `address` is ignored by transports that don't need it.
func create_host(_port: int, _max_clients: int) -> MultiplayerPeer:
	return null


## Connect to a host. For direct IP, `address` is an IP or hostname.
func create_client(_address: String, _port: int) -> MultiplayerPeer:
	return null


## Direct IP over ENet: LAN, port forwarding, or a VPN such as Tailscale.
class Enet:
	extends NetTransport

	func label() -> String:
		return "Direct IP (LAN or VPN)"

	func create_host(port: int, max_clients: int) -> MultiplayerPeer:
		var peer := ENetMultiplayerPeer.new()
		if peer.create_server(port, max_clients) != OK:
			return null
		return peer

	func create_client(address: String, port: int) -> MultiplayerPeer:
		var peer := ENetMultiplayerPeer.new()
		if peer.create_client(address, port) != OK:
			return null
		return peer
