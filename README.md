## Example

```lua
tarantool> tnet = require "tarantool_network"
tarantool> cfg = {}
tarantool> g = tnet.Graph:new(cfg)
tarantool> g:insert_node(1)
tarantool> g:insert_node(2)
tarantool> g:insert_edge(1, 2, 2)
tarantool> g:insert_edge(2, 1, 2)
tarantool> g:insert_edge(0, 2)
tarantool> g:insert_edge(0, 1, 4)
tarantool> g:insert_edge(3, 2, 2)
tarantool> g.edges_fields
---
- - name: source_id
    type: unsigned
  - name: target_id
    type: unsigned
  - name: weight
    type: unsigned
...
tarantool> g.edges:select{}
---
- - [0, 1, 4]
  - [0, 2, 1]
  - [1, 2, 2]
  - [2, 1, 2]
  - [3, 2, 2]
...
tarantool> g:dijkstra(0)
tarantool> g.nodes_fields
---
- - name: id
    type: unsigned
  - type: array
    name: shortest_path_from_0
    is_nullable: true
  - type: number
    name: shortest_path_from_0_length
    is_nullable: true
...
tarantool> g.nodes:select{}
---
- - [0, [0], 0]
  - [1, [0, 2, 1], 3]
  - [2, [0, 2], 1]
  - [3, null, inf]
...
```

