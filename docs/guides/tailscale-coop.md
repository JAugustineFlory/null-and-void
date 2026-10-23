# Co-op over the internet with Tailscale

Tailscale puts every player's computer on one private network, so Null & Void's lobby works as if you shared wifi. It's free for this use. Setup takes about 10 minutes the first time, and nothing is needed after that.

## Before you start
- One person is the **host**. Pick the one with the best internet connection.
- Everyone must run **the same version of the game** (it shows in a corner of the pause menu). Grab the newest from the [download page](https://jaugustineflory.github.io/null-and-void/). Mismatched versions can fail to connect or desync.

## 1. Everyone: install Tailscale and sign in
1. Download Tailscale from https://tailscale.com/download (Windows, Mac or Linux) and install it.
2. Open it and click **Log in**. Sign in with a Google, Microsoft, GitHub or Apple account. Everyone uses their **own** account.
3. On Windows the Tailscale icon sits in the system tray (bottom right). On Mac it's in the menu bar. It should say **Connected**.

## 2. Host: share your computer with the other players
This lets friends reach only your computer, not the rest of your network.
1. Open the admin console at https://login.tailscale.com/admin/machines.
2. Find your computer in the list and click the **...** menu on its row, then **Share...**
3. Click **Generate & copy invite link** (or enter each friend's email), and send the link to each player.
4. Each player opens the link, signs in with their own Tailscale account, and accepts.

(Alternative: under **Users → Invite users**, invite friends into your network. The free plan only allows a few users that way, so sharing the one machine is better for a group of up to 6.)

## 3. Host: find your Tailscale address
- Click the Tailscale icon. Under **This device** you'll see an address like **100.101.102.103**. Click it to copy.
- The game's lobby also lists it when you click **Host**: use the one that starts with **100.**

## 4. Play
1. **Host:** start the game, choose **Host**, and leave it on the lobby screen.
2. **Windows host:** if Windows asks whether to let the game (or Godot) communicate on networks, tick **both Private and Public** and click **Allow**. The Tailscale network often counts as Public.
3. **Everyone else:** choose **Join**, type the host's 100.x address, and keep the port at **7777**.
4. Up to 6 players can join. Ready up in the van as usual.

## If someone can't connect
- **Is Tailscale on?** Both computers must show Connected. A paused or logged-out Tailscale is the most common cause.
- **Can they see the host?** The friend opens Command Prompt (Windows) or Terminal (Mac) and runs `tailscale ping <host's 100.x address>`. A reply means the network works and the problem is the game or firewall.
- **Firewall:** on the host, open Windows Security → Firewall & network protection → Allow an app through firewall. Make sure the game (or Godot) is ticked for Private and Public.
- **Typo or stale address:** re-copy the host's 100.x address from the Tailscale icon.
- **Different game versions:** everyone downloads the newest version from the [download page](https://jaugustineflory.github.io/null-and-void/).
- **Only one copy hosting:** if the lobby says it couldn't host on port 7777, another copy of the game is already running on the host's computer. Close it.

## Afterwards
You can leave Tailscale installed and the share in place. Next time, everyone just makes sure Tailscale says Connected, and the host clicks Host.
