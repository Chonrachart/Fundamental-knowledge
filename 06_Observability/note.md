```text
Your Observability Stack — The Mental Model                                                                                                                                                      
   
  Think of it as 3 types of data flowing through a pipeline:                                                                                                                                       
                                                                  
  Your Apps / K8s Cluster                                                                                                                                                                          
          │                                                                                                                                                                                        
          ├── Metrics (numbers over time)    → Prometheus  → Grafana
          ├── Logs (text lines)              → Loki       → Grafana                                                                                                                                
          └── Traces (request journeys)      → Tempo      → Grafana                                                                                                                                
                                                                                                                                                                                                   
  What each piece does                                                                                                                                                                             
                                                                  
  ┌────────────┬───────────────────────────────────────────────────────────────────────┬───────────────────────────────────────────────────────────────────────────┐                               
  │ Component  │                                 Role                                  │                                  Analogy                                  │
  ├────────────┼───────────────────────────────────────────────────────────────────────┼───────────────────────────────────────────────────────────────────────────┤
  │ Grafana    │ UI — dashboards, alerts, search                                       │ The TV screen — displays everything, stores nothing                       │
  ├────────────┼───────────────────────────────────────────────────────────────────────┼───────────────────────────────────────────────────────────────────────────┤
  │ Prometheus │ Collects + stores metrics (CPU %, memory, request count, latency)     │ A thermometer that checks your servers every 15s and records the readings │                               
  ├────────────┼───────────────────────────────────────────────────────────────────────┼───────────────────────────────────────────────────────────────────────────┤                               
  │ Loki       │ Collects + stores logs (application output, error messages)           │ A filing cabinet for all your app's stdout/stderr                         │                               
  ├────────────┼───────────────────────────────────────────────────────────────────────┼───────────────────────────────────────────────────────────────────────────┤                               
  │ Tempo      │ Collects + stores traces (a single request's journey across services) │ A GPS tracker following one request through 5 microservices               │
  ├────────────┼───────────────────────────────────────────────────────────────────────┼───────────────────────────────────────────────────────────────────────────┤                               
  │ Kafka      │ Message bus — moves data between systems at scale                     │ A conveyor belt — producers put data on, consumers take data off          │
  └────────────┴───────────────────────────────────────────────────────────────────────┴───────────────────────────────────────────────────────────────────────────┘                               
                                                                  
  How they connect                                                                                                                                                                                 
                                                                  
  ┌─────────────┐     scrape every 15s     ┌────────────┐
  │  Your Pods   │ ◄──────────────────────── │ Prometheus │──┐                                                                                                                                     
  └─────────────┘                           └────────────┘  │                                                                                                                                      
         │                                                   │                                                                                                                                     
         │ logs (via agent)                                  │  query                                                                                                                              
         │                                  ┌────────────┐  │     
         ├─────────────────────────────────►│    Loki    │──┤                                                                                                                                      
         │                                  └────────────┘  │                                                                                                                                      
         │ traces (via agent)                                │                                                                                                                                     
         │                                  ┌────────────┐  ├──► Grafana                                                                                                                           
         └─────────────────────────────────►│   Tempo    │──┘                                                                                                                                      
                                            └────────────┘                                                                                                                                         
                                                                                                                                                                                                   
  Where does Kafka fit? — It sits between your apps and Loki/Tempo when you have high volume. Instead of sending logs/traces directly, apps send to Kafka, and Loki/Tempo consume from Kafka. This 
  prevents data loss during spikes. For a homelab, you likely don't need Kafka yet — it adds complexity and is only necessary at scale.
                                                                                                                                                                                                   
  Suggested learning order                                                                                                                                                                         
   
  1. Prometheus + Grafana — start here, most immediate value (see your cluster's CPU/memory/pods)                                                                                                  
  2. Loki + Grafana — add log search next (replaces kubectl logs) 
  3. Tempo + Grafana — add tracing later (only useful if you have multi-service apps)                                                                                                              
  4. Kafka — add last, only when direct ingestion becomes a bottleneck          
 ```