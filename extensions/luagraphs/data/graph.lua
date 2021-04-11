local graph = require('luagraphs.data.graph')

function graph:removeEdge(v, w)
    if self.directed then
        local list = self.adjList[v]
        if list ~= nil and list.N ~= 0 then
            for i = 0, list.N-1 do
                if list.a[i]:to() == w then
                    list:removeAt(i)
                    return
                end
            end
        end
    else
        local listFrom = self.adjList[v]
        local listTo = self.adjList[w]
        if listFrom ~= nil and listTo ~= nil and listFrom.N ~= 0 and listTo.N ~= 0 then
            if listFrom.N == 1 and listFrom.a[0]:to() == w then
                self:removeVertex(v)
                return
            elseif listTo.N == 1 and listTo.a[0]:from() == v then
                self:removeVertex(w)
                return
            end
            for i = 0, listFrom.N-1 do
                if listFrom.a[i]:to() == w then
                    listFrom:removeAt(i)
                    break
                end
            end
            for i = 0, listTo.N-1 do
                if listTo.a[i]:from() == v then
                    listTo:removeAt(i)
                    return
                end
            end
        end
    end
end

function graph:changeEdgeWeight(v, w, weight)
    if weight == nil then
        error("You must specify the new weight value for the provided edge")
    end
    local edges = self.adjList[v]
    if edges ~= nil then
        for i = 0, edges.N-1 do
            if edges.a[i]:to() == w then
                edges.a[i].weight = weight
                return
            end
        end
    end
end

function graph:changeAllEdgesWeightOfVertex(v, weight)
    if weight == nil then
        error("You must specify the new weight value for the provided edge")
    end
    local edges = self.adjList[v]
    if edges ~= nil then
        for i = 0, edges.N-1 do
            edges.a[i].weight = weight
        end
    end
end


return graph