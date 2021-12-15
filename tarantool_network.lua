#!/usr/bin/env tarantool

-- taken from: https://github.com/tarantool/moonwalker
local moonwalker = require "moonwalker"

Graph = {}

function Graph:new(cfg)
    -- Directed graph based on Tarantool
    new_graph = {}

    box.cfg(cfg)
    
    current_time = os.time()
    new_graph.nodes = box.schema.space.create("nodes"..current_time)
    new_graph.edges = box.schema.space.create("edges"..current_time)
    new_graph.nodes_fields = {{name = "id", type = "unsigned"}}
    new_graph.edges_fields = {{name = "source_id", type = "unsigned"}, 
                              {name = "target_id", type = "unsigned"},
			      {name = "weight", type = "unsigned"}}
    new_graph.nodes:format(new_graph.nodes_fields)
    new_graph.edges:format(new_graph.edges_fields)
    new_graph.nodes:create_index("primary", 
                                 {type = "tree", 
				  parts = {"id"}})
    new_graph.edges:create_index("primary", 
                                 {type = "tree", 
				  parts = {"source_id", "target_id"}})

    new_graph.num_nodes = 0
    new_graph.num_edges = 0

    self.__index = self
    setmetatable(new_graph, self)

    return new_graph
end

function Graph.insert_node(self, id)
    self.nodes:insert{id}
    self.num_nodes = self.num_nodes + 1
end

function Graph.insert_edge(self, source_id, target_id, weight)
    if weight == nil then 
        weight = 1
    end
    
    self.edges:insert{source_id, target_id, weight}
    self.num_edges = self.num_edges + 1

    pcall(self.insert_node, self, source_id)
    pcall(self.insert_node, self, target_id)
end

function Graph.insert_nodes_from_file(self, filepath)
    for line in io.lines(filepath) do
	if line ~= nil then
            local id = tonumber(line)
	    self:insert_node(id)
	end
    end
end

function Graph.insert_edges_from_file(self, filepath, sep)
    if sep == nil then
        sep = " "
    end

    for line in io.lines(filepath) do
	if line ~= nil then
	    local edge = {}
            for id in string.gmatch(line..sep, "(.-)"..sep) do
	        table.insert(edge, tonumber(id))
	    end
	    self:insert_edge(edge[1], edge[2], edge[3])
	end
    end
end

function Graph.dijkstra(self, source_id)
    -- Dijkstra's algorithm implementation:
    -- (https://neerc.ifmo.ru/wiki/index.php?title=Алгоритм_Дейкстры);
    -- Finds shrotest paths from `source_id` node to each other
    -- nodes in the graph in O(|V|^2) time.
    local path_field = "shortest_path_from_"..source_id
    local length_field = path_field.."_length"

    table.insert(self.nodes_fields,
                 {name = path_field, type = "array", is_nullable=true})
    table.insert(self.nodes_fields,
                 {name = length_field, type = "number", is_nullable=true})
    
    self.nodes:format(self.nodes_fields)
    
    moonwalker{space=self.nodes, 
               actor=function(node)
	             self.nodes:update({node.id}, 
		                       {{"=", length_field, math.huge}})
		     end,
	       silent=true
	     }
    
    local used = {}
    local min_length_node = nil
    self.nodes:update({source_id}, {{"=", path_field, {source_id}},
                                    {"=", length_field, 0}})
    
    for i=1, self.num_nodes do
	-- Find a node with minimum length of path from the source
	min_length_node = nil
	for _, node in self.nodes:pairs() do
	    if not used[node.id]
	       and (min_length_node == nil 
	            or node[length_field] < min_length_node[length_field]) then
                min_length_node = node
	    end
	end
	
	if min_length_node[length_field] == math.huge then
	    break
	end

	used[min_length_node.id] = true

	-- Edge relaxation
	for _, edge in self.edges:pairs{min_length_node.id} do
	    local target_length = self.nodes:select{edge.target_id}[1][length_field]
	    if min_length_node[length_field] + edge.weight < target_length then
		local target_path = min_length_node[path_field]
		table.insert(target_path, edge.target_id)
	        self.nodes:update({edge.target_id},
		                  {{"=", path_field, target_path},
				   {"=", length_field, min_length_node[length_field] + edge.weight}})
	    end
	end
    end
end

return {
    Graph = Graph;
}
