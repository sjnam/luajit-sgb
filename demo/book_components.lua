--[[
   @* Bicomponents. This demonstration program computes the
   biconnected components of GraphBase graphs derived from world literature,
   using a variant of Hopcroft and Tarjan's algorithm [R. E. Tarjan, ``Depth-first
   search and linear graph algorithms,'' {\sl SIAM Journal on Computing\/
   \bf1} (1972), 146--160]. Articulation points and ordinary (connected)
   components are also obtained as byproducts of the computation.

   Two edges belong to the same  biconnected component---or ``bicomponent''
   for short---if and only if they are identical or both belong to a
   simple cycle. This defines an equivalence relation on edges.
   The bicomponents of a connected graph form a
   free tree, if we say that two bicomponents are adjacent when they have
   a common vertex (i.e., when there is a vertex belonging to at least one edge
   in each of the bicomponents). Such a vertex is called an {\sl articulation
   point\/}; there is a unique articulation point between any two adjacent
   bicomponents. If we choose one bicomponent to be the ``root'' of the
   free tree, the other bicomponents can be represented conveniently as
   lists of vertices, with the articulation point that leads toward the root
   listed last. This program displays the bicomponents in exactly that way.

   @ We permit command-line options in typical \UNIX/ style so that a variety of
   graphs can be studied: The user can say `\.{-t}\<title>',
   `\.{-n}\<number>', `\.{-x}\<number>', `\.{-f}\<number>',
   `\.{-l}\<number>', `\.{-i}\<number>', `\.{-o}\<number>', and/or
   `\.{-s}\<number>' to change the default values of the parameters in
   the graph generated by |book(t,n,x,f,l,i,o,s)|.

   When the bicomponents are listed, each character in the book is identified by
   a two-letter code, as found in the associated data file.
   An explanation of these codes will appear first if the \.{-v} or \.{-V} option
   is specified. The \.{-V} option prints a fuller explanation than~\.{-v}; it
   also shows each character's weighted number of appearances.

   The special command-line option \.{-g}$\langle\,$filename$\,\rangle$
   overrides all others. It substitutes an external graph previously saved by
   |save_graph| for the graphs produced by |book|.
--]]

local ffi = require "ffi"
local sgb = require "sgb"
local gb = sgb.gb

local ffi_new = ffi.new
local str = ffi.string
local print = print
local ipairs = ipairs
local tonumber = tonumber
local io_write = io.write
local sformat = string.format
local arcs = sgb.arcs
local vertices = sgb.vertices
local short_code = sgb.short_code
local restore_graph = sgb.restore_graph
local book = sgb.book
local desc = sgb.desc
local in_count = sgb.in_count
local out_count = sgb.out_count


local function printf (...)
   io_write(sformat(...))
end


local function rank (v)
   return tonumber(v.z.I)
end
local function set_rank (v, n)
   v.z.I = n
end


local function parent (v)
   return v.y.V
end
local function set_parent (v, v1)
   v.y.V = v1
end


local function untagged (v)
   return v.x.A
end
local function set_untagged (v, v1)
   v.x.A = v1
end


local function link (v)
   return v.w.V
end
local function set_link (v, v1)
   v.w.V = v1
end


local function min (v)
   return v.v.V
end
local function set_min (v, v1)
   v.v.V = v1
end


local function arc_from (v)
   return v.x.V
end
local function set_arc_from (v, v1)
   v.x.V = v1
end


local nn
local dummy = ffi_new("Vertex")
local active_stack
local artic_pt
local filename
local code_name = ffi_new("char[3][3]")


local function vertex_name (v, i)
   if filename ~= nil then
      return str(v.name)
   end
   code_name[i][0] = gb.imap_chr(short_code(v) / 36)
   code_name[i][1] = gb.imap_chr(short_code(v) % 36)
   return str(code_name[i])
end


-- main

local v
local t = "anna"
local n, x, f, l = 0, 0, 0, 0
local i, o, s = 1, 1, 0

for _, a in ipairs(arg) do
   local v = a:match("-t(%a+)")
   if v then
      t = v
   else
      local k, v = a:match("-(%a)(%d+)")
      if k == "n" then
         n = tonumber(v)
      elseif k == "x" then
         x = tonumber(v)
      elseif k == "f" then
         f = tonumber(v)
      elseif k == "l" then
         l = tonumber(v)
      elseif k == "i" then
         i = tonumber(v)
      elseif k == "o" then
         o = tonumber(v)
      elseif k == "s" then
         s = tonumber(v)
      else
         k, v = a:match("-(%a)")
         if k == "v" then
            gb.verbose = 1
         elseif k == "V" then
            gb.verbose = 2
         else
            filename = a:match("-g(%a+)")
            if not filename then
               printf("Usage: %s [-ttitle][-nN][-xN][-fN][-lN][-iN][-oN][-sN][-v][-gfoo]\n",
                      arg[0])
               return
            end
         end
      end
   end
end

if filename then
   gb.verbose = 0
end

local g
if filename then
   g = restore_graph(filename)
else
   g = book(t, n, x, f, l, i, o, s)
end

if not g then
   printf("Sory, can't create the graph! (error code %d)\n", gb.panic_code)
end

printf("Biconnectivity analysis of %s\n\n", str(g.id))

for v in vertices(g) do
   if gb.verbose == 1 then
      printf("%s=%s\n", vertex_name(v, 0), str(v.name))
   else
      printf("%s=%s, %s [weight %d]\n", vertex_name(v, 0), str(v.name),
             desc(v), i * in_count(v) + o * out_count(v))
   end
end
print()

for v in vertices(g) do
   set_rank(v, 0)
   set_untagged(v, v.arcs)
end

nn = 0
active_stack = nil
set_rank(dummy, 0)

for vv in vertices(g) do
   if rank(vv) == 0 then
      v = vv
      set_parent(v, dummy)
      nn = nn + 1
      set_rank(v, nn)
      set_link(v, active_stack)
      active_stack = v
      set_min(v, parent(v))
      repeat
         local u
         local a = untagged(v)
         if a ~= nil then
            u = a.tip
            set_untagged(v, a.next)
            if rank(u) ~= 0 then
               if rank(u) < rank(min(v)) then
                  set_min(v, u)
               end
            else
               set_parent(u, v)
               v = u
               nn = nn + 1
               set_rank(v, nn)
               set_link(v, active_stack)
               active_stack = v
               set_min(v, parent(v))
            end
         else
            u = parent(v)
            if min(v) == u then
               if u == dummy then
                  if artic_pt ~= nil then
                     printf(" and %s (this ends a connected component of the graph)\n",
                            vertex_name(artic_pt, 0))
                  else
                     printf("Isolated vertex %s\n", vertex_name(v, 0))
                  end
                  active_stack = nil
                  artic_pt = nil
               else
                  if artic_pt ~= nil then
                     printf(" and articulation point %s\n", vertex_name(artic_pt, 0))
                  end
                  t = active_stack
                  active_stack = link(v)
                  printf("Bicomponent %s", vertex_name(v, 0))
                  if t == v then
                     print()
                  else
                     printf(" also includes:\n")
                     while t ~= v do
                        printf(" %s (from %s; ..to %s)\n",
                               vertex_name(t, 0),
                               vertex_name(parent(t), 1),
                               vertex_name(min(t), 2))
                        t = link(t)
                     end
                  end
                  artic_pt = u
               end
            elseif rank(min(v)) < rank(min(u)) then
               set_min(u, min(v))
            end
            v = u
         end
      until v == dummy
   end
end
