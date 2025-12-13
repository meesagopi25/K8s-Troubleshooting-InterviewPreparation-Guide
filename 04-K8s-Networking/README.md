This is the most common and robust way to access a Service in Kubernetes, as it relies on the cluster's **Service Discovery** mechanism (CoreDNS).

By using `wget http://web-svc:80`, you triggered the **full, end-to-end communication workflow**, which includes both DNS resolution and Kube-proxy redirection.

Here is the step-by-step workflow for the command you executed:

---

### Full Workflow: Pod-to-Service Communication via Service Name

The workflow starts with the `dnsutils` Pod having to resolve the name `web-svc` before it can initiate the connection to the ClusterIP.

#### Step 1: DNS Resolution (The Lookup)

This is the key difference from your previous example. The client first needs to find the IP address for the name `web-svc`.

1.  **Client Query:** The `wget` application inside the `dnsutils` Pod attempts to connect to `web-svc` on port `80`.
2.  **FQDN Construction:** Since `web-svc` is a short name, the C library inside the `dnsutils` Pod uses the search path defined in `/etc/resolv.conf` to build the Fully Qualified Domain Name (FQDN), assuming the Service is in the same namespace (e.g., `default`):
    * **FQDN:** `web-svc.default.svc.cluster.local`
3.  **DNS Request:** The Pod sends a DNS query for the FQDN to the **CoreDNS ClusterIP** (e.g., `10.96.0.10`).
4.  **DNS Response:** CoreDNS looks up the Service record for `web-svc` and returns its **ClusterIP**: **`10.96.183.211`**. 
5.  **Connection Setup:** The `wget` client receives this IP and immediately initiates a TCP connection to **`10.96.183.211:80`** (which is reflected in your output: `Connecting to web-svc:80 (10.96.183.211:80)`).

#### Step 2: Traffic Interception by Kube-proxy

The connection packet now leaves the `dnsutils` Pod destined for the virtual IP `10.96.183.211`.

1.  **Packet Out:** The packet leaves the `dnsutils` Pod with the destination IP `10.96.183.211`.
2.  **Kube-proxy Intercepts:** The packet hits the Linux network stack of the Node where the `dnsutils` Pod is running. **Kube-proxy** rules intercept any traffic destined for a Service ClusterIP.
3.  **Load Balancing Choice:** Kube-proxy consults its Endpoints list for `web-svc` (`10.244.1.20`, `10.244.2.30`, etc.). It selects one available backend Pod using a load-balancing algorithm. *Let's assume it selects **`10.244.2.30`**.*
4.  **Destination NAT (DNAT):** Kube-proxy rewrites the packet's destination headers:
    * **New Destination IP:** `10.244.2.30` (A real Pod IP).
    * **New Destination Port:** `80` (The target port). 

#### Step 3: Final Delivery and Response

1.  **Routing:** The packet, now destined for the real Pod IP `10.244.2.30`, is routed across the CNI network to the Node hosting that Pod.
2.  **Delivery:** The packet reaches the network interface of the backend Pod at `10.244.2.30`.
3.  **Processing:** The web application processes the HTTP request.
4.  **Reverse NAT:** The response packet is sent back, and the kernel automatically reverses the DNAT, making the source IP appear to be the **ClusterIP** (`10.96.183.211`) to the client.
5.  **Completion:** The response (the `index.html` data) is delivered back to the `dnsutils` Pod, and the `wget` command successfully completes.

---

### Key Takeaway

The core networking (Steps 2 and 3) is identical to your previous example. The crucial difference here is **Step 1 (DNS)**, which is why using the Service Name (`web-svc`) is considered best practice:

* It makes your applications portable (you don't hardcode the ClusterIP).
* It ensures you are always talking to the correct, currently active ClusterIP.
