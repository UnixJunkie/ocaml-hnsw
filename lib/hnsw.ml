open Base
open Stdio

module type DISTANCE = sig
  type value [@@deriving sexp]
  val distance : value -> value -> float
end

(* module NeighbourSet = struct *)
(*   (\* gah! I wish I knew how to just say module Neighbours = Set *)
(*      with type t = Set.M(Int) or whatever *\) *)
(*   type t = Set.M(Int).t [@@deriving sexp] *)
(*   (\* type nonrec node = node *\) *)

(*   let create () = Set.empty (module Int) *)
(*   let singleton n = Set.singleton (module Int) n *)
(*   let add n node = Set.add n node *)
(*   let remove n node = Set.remove n node *)
(*   let length c = Set.length c *)
(*   let for_all n ~f = Set.for_all n ~f *)
(*   let fold c ~init ~f = *)
(*     Set.fold c ~init ~f *)

(*   (\* let diff a b = *\) *)
(*   (\*   Set.diff a b *\) *)

(*   let diff_both a b = *)
(*     Set.diff b a, Set.diff a b *)

(*   (\* let union a b = Set.union a b *\) *)
(* end *)

module NeighbourList = struct
  type t = { list : int list; length : int } [@@deriving sexp]

  let create () = { list=[]; length=0 }
  let singleton n = { list=[n]; length=1 }
  let add n node = { list=node::n.list; length=n.length+1 }
  let remove n node = let l = List.filter n.list ~f:(fun x -> x <> node) in
    { list=l; length=List.length l} (*  XXX could optimize length computation  *)
  let length c = c.length
  let for_all n ~f = List.for_all n.list ~f
  let fold c ~init ~f =
    List.fold_left c.list ~init ~f

  (* let diff a b = *)
  (*   Set.diff a b *)

  let diff_both a b =
    let sa = Set.of_list (module Int) a.list in
    let sb = Set.of_list (module Int) b.list in
    let dba = Set.diff sb sa in
    let dab = Set.diff sa sb in
    dba, dab

  let is_empty n = match n.list with
    | [] -> true
    | _ -> false
  (* let union a b = Set.union a b *)
end

module MapGraph = struct
  (* type nonrec node = node [@@deriving sexp] *)
  (* type nonrec value = value [@@deriving sexp] *)
  type node = int [@@deriving sexp]

  module Neighbours = NeighbourList

  type t = {
    (* values : value Map.M(Int).t; *)
    connections : Neighbours.t Map.M(Int).t;
    (* next_available_node : int *)
    max_node_id : int
  } [@@deriving sexp]

  let max_node_id x = x.max_node_id

  (* module VisitedSet = struct
   *   type t_graph = t
   *   type t = Set.M(Int).t [@@deriving sexp]
   *   let create graph = Set.empty (module Int)
   *   (\* type visit = Already_visited | New_visit of t *\)
   *   (\* let visit visited node = *\)
   *   (\*   let new_visited = Set.add visited node in *\)
   *   (\*   if phys_equal new_visited visited then Already_visited *\)
   *   (\*   else New_visit new_visited *\)
   *   let mem visited node = Set.mem visited node
   *   let add visited node = Set.add visited node
   * end *)

  (* module VisitedArray = struct
   *   type t_graph = t
   *   type t = bool array [@@deriving sexp]
   *   let create graph = Array.create ~len:(max_node_id graph + 1) false
   *   (\* type visit = Already_visited | New_visit of t *\)
   *   (\* let visit visited node = *\)
   *   (\*   let new_visited = Set.add visited node in *\)
   *   (\*   if phys_equal new_visited visited then Already_visited *\)
   *   (\*   else New_visit new_visited *\)
   *   let mem visited node = visited.(node)
   *   let add visited node = visited.(node) <- true; visited
   *   let length a = Array.fold a ~init:0 ~f:(fun acc e -> if e then acc+1 else acc)
   * end *)

  module VisitedIntArray = struct
    type t_graph = t
    type t = { visited : int array; mutable epoch : int } [@@deriving sexp]
    let create graph = { visited = Array.create ~len:(max_node_id graph + 1) 0; epoch = 1 }
    (* type visit = Already_visited | New_visit of t *)
    (* let visit visited node = *)
    (*   let new_visited = Set.add visited node in *)
    (*   if phys_equal new_visited visited then Already_visited *)
    (*   else New_visit new_visited *)
    let mem visited node = visited.visited.(node) >= visited.epoch
    let add visited node = visited.visited.(node) <- visited.epoch; visited
    let length a = Array.fold a.visited ~init:0 ~f:(fun acc e -> if e >= a.epoch then acc+1 else acc)
    let clear (visited : t) =
      visited.epoch <- visited.epoch + 1;
      visited
      (* { visited with epoch = visited.epoch+1 } *)
  end
  
  module Visited = VisitedIntArray
  
  (*  XXX TODO: check symmetric  *)
  let invariant _x = true
  (* let invariant x = *)
  (*   Map.for_alli x.connections ~f:(fun ~key ~data -> *)
  (*       Map.mem x.values key && Neighbours.for_all data ~f:(Map.mem x.values)) *)


  let create max_node_id =
    { (* values; *)
      connections = Map.empty (module Int);
      max_node_id
      (* next_available_node = 0 *) }

  let fold_neighbours g node ~init ~f =
    match Map.find g.connections node with
    | None -> init
    | Some neighbours ->
      Neighbours.fold neighbours ~init ~f

  (* let distance a b = Distance.distance a b *)

  let adjacent g node =
    match Map.find g.connections node with
    | None -> Neighbours.create ()(* Set.empty (module Int) *)
    | Some neighbours -> neighbours

  let num_nodes g = Map.length g.connections
  
  let connect_symmetric g node neighbours =
    (* assert (invariant g); *)
    (* assert (Neighbours.for_all neighbours ~f:(Map.mem g.values)); *)
    (* assert (Map.mem g.values node); *)
    let connections = Map.set g.connections ~key:node ~data:neighbours in
    let g =
      { g with connections = Neighbours.fold neighbours ~init:connections
                   ~f:(fun connections neighbour ->
                       let neighbours_of_neighbour = match Map.find connections neighbour with
                         | None -> Neighbours.singleton node
                         | Some old_neighbours -> Neighbours.add old_neighbours node
                       in
                       Map.set connections ~key:neighbour ~data:neighbours_of_neighbour) }
    in
    (* assert (invariant g); *)
    g

  (* let insert g value neighbours = *)
  (*   let connect_symmetric connections node neighbours = *)
  (*     let connections = Map.set connections node neighbours in *)
  (*     Neighbours.fold neighbours ~init:connections ~f:(fun connections neighbour -> *)
  (*         let neighbours_of_neighbour = match Map.find connections neighbour with *)
  (*           | None -> Set.singleton (module Int) node *)
  (*           | Some old_neighbours -> Set.add old_neighbours node *)
  (*         in *)
  (*         Map.set connections neighbour neighbours_of_neighbour) *)
  (*   in *)
  (*   TODO *)
  (*     solve the node registry problem: *)
  (*     maybe the layergraph abstraction does not work? how to insert a node in there? *)
  (*     inserting a node into the layergraph should modify the hgraph as well (since it holds values) *)
  (*   { (\* values = Map.set g.values g.next_available_node value; *\) *)
  (*     connections = connect_symmetric g.connections g.next_available_node neighbours; *)
  (*     (\* next_available_node = g.next_available_node + 1 *\) } *)

  (* let add_neighbours g node added_neighbours = *)
  (*   (\* let connections = Map.set g.connections node (Neighbours.union (adjacent g node) added_neighbours) in *\) *)
  (*   let connections = Map.update g.connections node (function *)
  (*       | None -> added_neighbours *)
  (*       | Some old_neighbours -> Neighbours.union old_neighbours added_neighbours) in *)
  (*   let connections = Neighbours.fold added_neighbours ~init:connections *)
  (*       ~f:(fun connections added_neighbour -> *)
  (*           Map.update connections added_neighbour ~f:(function *)
  (*               | None -> Set.singleton (module Int) node *)
  (*               | Some old -> Set.add old node)) *)
  (*   in let g = { connections } in *)
  (*   (\* assert (invariant g); *\) *)
  (*   g *)

  (* let remove_neighbours g node removed_neighbours = *)
  (*   let connections = Map.update g.connections node (function *)
  (*       | None -> Neighbours.create () *)
  (*       | Some old -> Neighbours.diff old removed_neighbours) in *)
  (*   let connections = Neighbours.fold removed_neighbours ~init:connections *)
  (*       ~f:(fun connections removed_neighbour -> *)
  (*           Map.update connections removed_neighbour ~f:(function *)
  (*               | None -> Set.empty (module Int) *)
  (*               | Some old -> Set.remove old node)) *)
  (*   in let g = { connections } in *)
  (*   (\* assert (invariant g); *\) *)
  (*   g *)

  let isolated layer =
    Map.fold layer.connections ~init:([]) ~f:(fun ~key ~data acc ->
        if Neighbours.is_empty data then key::acc else acc)

  let check_isolated layer context =
    match isolated layer with
    | [] -> []
    | iso -> printf "%s: isolated: %s\n%!" context (Sexp.to_string_hum @@ [%sexp_of : int list] iso); iso
  
  let set_connections layer node neighbours =
    (* if Neighbours.is_empty neighbours then *)
      (* printf "set_connections %d called with no neighbours\n%!" node; *)
    (* let _ = check_isolated layer (Printf.sprintf "before set_connections %d %s" node
     *                                 (Sexp.to_string_hum @@ [%sexp_of : Neighbours.t] neighbours))
     * in *)
    let old_neighbours = adjacent layer node in
    let added_neighbours, removed_neighbours = Neighbours.diff_both old_neighbours neighbours in
    (* let added_neighbours = Neighbours.diff neighbours old_neighbours in *)
    (* let layer = add_neighbours layer node added_neighbours in *)
    (* let layer = remove_neighbours layer node removed_neighbours in *)
    let connections = layer.connections in
    (*  1. set the connections for the node  *)
    let connections = Map.update connections node ~f:(function
        | None -> neighbours
        | Some _ -> neighbours)
    in
    (*  2. remove link to node from removed connections  *)
    let connections = Set.fold removed_neighbours ~init:connections
        ~f:(fun connections removed_neighbour ->
            Map.update connections removed_neighbour ~f:(function
                | None -> assert false
                | Some old -> Neighbours.remove old node))
    in
    (*  2. add link to node to added connections  *)
    let connections = Set.fold added_neighbours ~init:connections
        ~f:(fun connections added_neighbour ->
            Map.update connections added_neighbour ~f:(function
                | None -> Neighbours.singleton node
                | Some old -> Neighbours.add old node))
    in
    let ret = { layer with connections } in
    (* let iso = check_isolated ret (Printf.sprintf "after set_connections %d %s" node
     *                                 (Sexp.to_string_hum @@ [%sexp_of : Neighbours.t] neighbours))
     * in *)
    (* List.iter iso ~f:(fun n -> printf "previous neighbours of %d: %s\n%!"
     *                      n (Sexp.to_string_hum @@ [%sexp_of : Neighbours.t] @@ adjacent layer n)); *)
    (* Neighbours.fold neighbours ~init:() ~f:(fun () n ->
     *     let nn = adjacent { layer with connections } n in
     *     if Neighbours.is_empty nn then
     *       printf "after set_connections %d %s, %d has no neighbours\n%!"
     *         node (Sexp.to_string_hum (Neighbours.sexp_of_t neighbours)) n); *)
    ret
end

module type VALUE = sig
  type value [@@deriving sexp]
end

module type VALUES = (* functor (Value : VALUE) -> *) sig
  (* type node [@@deriving sexp] *)
  (* type value [@@deriving sexp] *)
  type t [@@deriving sexp]
  type value [@@deriving sexp]

  val length : t -> int
  val value : t -> int -> value
end

module MapValues(Value : VALUE) = struct
  type node = int [@@deriving sexp]
  type value = Value.value [@@deriving sexp]
  type t = {
    values : Value.value Map.M(Int).t;
    next_node : int;
  } [@@deriving sexp]

  let create () = {
    values = Map.empty (module Int);
    next_node = 0;
  }
  let length m = Map.length m.values
  let value m k = Map.find_exn m.values k
  let allocate m v =
    let node = m.next_node in
    let values = Map.set m.values ~key:node ~data:v in
    {
      values; 
      next_node = m.next_node + 1
    }, node
end

module BaValues = struct
  type node = int [@@deriving sexp]
  type t = Lacaml.S.mat sexp_opaque [@@deriving sexp]
  type value = Lacaml.S.vec sexp_opaque [@@deriving sexp]

  let create ba = ba
  let length m = Lacaml.S.Mat.dim2 m
  let value m k = Lacaml.S.Mat.col m k
  let foldi (m : t)  ~init ~f =
    let n = Lacaml.S.Mat.dim2 m in
    let k_print = max (n / 100) 1 in
    Lacaml.S.Mat.fold_cols
      (fun (i, acc) col ->
         if i % k_print = 0 then begin
           printf "\r              \r%d/%d %d%%%!" i n
             (Int.of_float (100. *. Float.of_int i /. Float.of_int n));
         end;
         (i+1, f acc i col)
      )
      (1, init) m |> snd
end

(* module Dummy = (MapValues : VALUES) *)

module Hgraph(Values : VALUES)(Distance : DISTANCE) = struct
  (* module Values = Values(Distance) *)

  type node = int [@@deriving sexp]
  type value = Distance.value [@@deriving sexp]

  module LayerGraph = MapGraph
  (* struct *)
  (*   type nonrec node = node [@@deriving sexp] *)
  (*   include MapGraph *)
  (* end *)

  type t = {
    layers : LayerGraph.t Map.M(Int).t;
    max_layer : int;
    entry_point : node;
    values : Values.t; (* value Map.M(Int).t; *)
    (* next_available_node : int *)
  } [@@deriving sexp]

  let fold_layers ~init ~f h =
    Map.fold h.layers ~init ~f
  
  module Stats = struct
    type mima = { min : int; max : int; mean : float; isolated : int list } [@@deriving sexp]
    type t = {
      num_nodes : int;
      layer_sizes : int Map.M(Int).t;
      layer_connectivity : mima Map.M(Int).t;
    } [@@deriving sexp]

    let min_max_connectivity g =
      let mi, ma, n, sum, isolated =
        Map.fold g.LayerGraph.connections ~init:(1000000, -1, 0, 0., []) ~f:(fun ~key ~data (mi, ma, n, sum, isolated) ->
            let num_neighbours = LayerGraph.Neighbours.length data in
            let isolated = if num_neighbours > 0 then isolated else key::isolated in
            (min num_neighbours mi, max num_neighbours ma, n+1, sum+.Float.of_int num_neighbours, isolated))
      in { min=mi; max=ma; mean= sum /. Float.of_int n; isolated }

    let compute hgraph =
      {
        num_nodes = Values.length hgraph.values;
        layer_sizes = Map.map hgraph.layers ~f:(fun layer -> Map.length layer.connections);
        layer_connectivity = Map.map hgraph.layers ~f:min_max_connectivity
      }
  end

  exception Value_not_found of string
  let value h node =
    Values.value h.values node
  (* Map.find_exn h.values node *)
  (* match Map.find h.values node with *)
  (* | None -> raise (Value_not_found (Printf.sprintf "node: %s\nvalues:\n%s" *)
  (*                                     (Sexp.to_string_hum (sexp_of_node node)) *)
  (*                                     (Sexp.to_string_hum ([%sexp_of : Map.M(Int).t] sexp_of_value h.values)))) *)
  (* | Some node -> node *)

  (*  not great! entry_point is invalid when the net is empty!  *)
  let create (values : Values.t) =
    { layers = Map.empty (module Int);
      max_layer = 0;
      entry_point = -1;
      values = values; (* Map.empty (module Int); *)
      (* next_available_node = 0 *)
    }

  let max_node_id g = Values.length g.values
  
  let is_empty h = h.entry_point < 0 (* Map.is_empty h.values *)

  (* let layer hgraph i = Map.find_exn hgraph.layers i *)
  let layer hgraph i = match Map.find hgraph.layers i with
    | Some layer -> layer
    | None -> LayerGraph.create (max_node_id hgraph)

  let max_layer hgraph = hgraph.max_layer
  let set_max_layer hgraph m =
    { hgraph with max_layer = m;
                  layers = Map.set hgraph.layers ~key:m ~data:(layer hgraph m) }

  (* Not well defined when the graph is empty, and no check that the
     entry point is an actual node. However the neighbour sets should
     be returned as empty if the node is not found, so maybe this is
     not a problem. *)
  let entry_point h = h.entry_point
  let set_entry_point h p =
    (* printf "setting entry point: %d\n%!" p; *)
    { h with entry_point = p }

  (* let allocate_node h = *)
  (*   h.next_available_node, { h with next_available_node = h.next_available_node+1 } *)

  (* let allocate h value = *)
  (*   let node, h = allocate_node h in *)
  (*   { h with values = Map.set h.values node value }, node *)

  let invariant h =
    Map.for_all h.layers ~f:LayerGraph.invariant

  (* let insert h i_layer value neighbours = *)
  (*   let h, node = allocate h value in *)
  (*   (\* assert (invariant h); *\) *)
  (*   (\* assert (Map.mem h.values node); *\) *)
  (*   let layer = layer h i_layer in *)
  (*   (\* assert (LayerGraph.invariant layer); *\) *)
  (*   let updated_layer = LayerGraph.connect_symmetric layer node neighbours in *)
  (*   let h = { h with layers = Map.set h.layers i_layer updated_layer } in *)
  (*   (\* assert (invariant h); *\) *)
  (*   h *)

  let set_connections h i_layer node neighbours =
    let layer = LayerGraph.set_connections (layer h i_layer) node neighbours in
    { h with layers = Map.set h.layers ~key:i_layer ~data:layer }
end

module HgraphIncr(Distance : DISTANCE) = struct
  module MapValues = MapValues(Distance)
  include Hgraph(MapValues)(Distance)
  let allocate x value =
    let values, node = MapValues.allocate x.values value in
    { x with values }, node
  let create () = create (MapValues.create ())
end

module HgraphBatch(Distance : DISTANCE with type value = Lacaml.S.vec) = struct
  include Hgraph(BaValues)(Distance)
  module Values = BaValues
  let create ba = create (BaValues.create ba)
end

(* module Value(Distance : DISTANCE) = struct *)
(*   module Hgraph = Hgraph(Distance) *)
(*   type t = Hgraph.t [@@deriving sexp] *)
(*   type node = Hgraph.node [@@deriving sexp] *)
(*   type value = Hgraph.value *)
(*   let value g n = Hgraph.value g n *)
(* end *)

type 'a value_distance = 'a Hnsw_algo.value_distance [@@deriving sexp]

module Nearest(Distance : DISTANCE)(Value : Hnsw_algo.VALUE with type value = Distance.value) = struct
  (* module Hgraph = HgraphIncr(Distance) *)
  type t_value_computer = Value.t (* [@@deriving sexp] *)
  type node = Value.node [@@deriving sexp]
  type value = Value.value [@@deriving sexp]
  module MaxHeap = Hnsw_algo.MaxHeap(Distance)(Value)

  (* type graph = t [@@deriving sexp] *)
  type t = { value_computer : t_value_computer sexp_opaque;
             target : value;
             size : int;
             max_size : int;
             max_priority_queue : MaxHeap.t } [@@deriving sexp]

  let value_computer x = x.value_computer
  let target x = x.target

  let create value_computer target ~ef =
    { value_computer; target; size=0; max_size=ef; max_priority_queue=MaxHeap.create () }

  let length q = q.size

  type insert = Too_far | Inserted of t

  let insert_distance q (element : node value_distance) =
    let size = length q in
    if size < q.max_size then
      Inserted { q with max_priority_queue = MaxHeap.add q.max_priority_queue element; size=q.size+1 }
    else begin match MaxHeap.max q.max_priority_queue with
      | None -> Too_far
      | Some max_element ->
        if not @@ MaxHeap.Element.is_further element max_element
        then
          let new_heap = MaxHeap.add q.max_priority_queue element |> MaxHeap.remove_max in
          Inserted { q with max_priority_queue = new_heap }
        else Too_far
    end

  (* let insert q node = *)
  (*   let new_element = MaxHeap.Element.of_node q.target q.value_computer node in *)
  (*   insert_distance q new_element *)

  let fold x ~init ~f = MaxHeap.fold x.max_priority_queue ~init ~f:(fun acc e -> f acc e.node)
  let fold_distance x ~init ~f = MaxHeap.fold x.max_priority_queue ~init ~f:(fun acc e -> f acc e)
  let max_distance x =
    match MaxHeap.max x.max_priority_queue with
    | Some e -> e.Hnsw_algo.distance_to_target
    | None -> Float.neg_infinity

  let fold_far_to_near x ~init ~f =
    MaxHeap.fold_far_to_near_until x.max_priority_queue ~init ~f:(fun acc e -> MaxHeap.Continue (f acc e))

  let nearest_k n k =
    let ret,_ =
      fold_far_to_near n ~init:([], 0) ~f:(fun (acc, m) e -> if m < k then (e::acc, m+1) else (acc, m))
    in ret
end

(* module Nearest(Distance : DISTANCE) = struct *)
(*   module N = NearestOne(Distance) *)
(*   type t = { *)
(*     (\* XXX This is a reasonable repr if k > ef. For k <= ef, we could *)
(*        keep only one heap. (Not sure it matters highly.) *)
(*     *\) *)
(*     ef : N.t; *)
(*     k : N.t *)
(*   } [@@deriving sexp] *)
(*   type value = N.value [@@deriving sexp] *)
(*   type node = N.node [@@deriving sexp] *)
(*   type t_value_computer = N.t_value_computer [@@deriving sexp] *)

(*   let create value_computer target ~ef ~k = *)
(*     { *)
(*       ef = N.create value_computer target ef; *)
(*       k = N.create value_computer target k *)
(*     } *)
(*   let target n = N.target n.ef *)
(*   let value_computer n = N.value_computer n.ef *)

(*   type insert = Too_far | InsertedEf of t | InsertedNotEf of t *)

(*   let insert_distance n (node : node value_distance) = *)
(*     match N.insert_distance n.ef node, N.insert_distance n.k node with *)
(*     | Too_far, Too_far -> Too_far *)
(*     | Inserted ef, Inserted k -> InsertedEf { ef; k } *)
(*     | Inserted ef, Too_far -> InsertedEf { ef; k=n.k } *)
(*     | Too_far, Inserted k -> InsertedNotEf { ef=n.ef; k } *)

(*   (\* let insert n node = *\) *)
(*   (\*   (\\* XXX the distance to target is computed twice here, we should *\) *)
(*   (\*      share it *\\) *\) *)
(*   (\*   (\\*  XXX can we remove this?  *\\) *\) *)
(*   (\*   match N.insert n.ef node, N.insert n.k node with *\) *)
(*   (\*   | Too_far, Too_far -> Too_far *\) *)
(*   (\*   | Inserted ef, Inserted k -> InsertedEf { ef; k } *\) *)
(*   (\*   | Inserted ef, Too_far -> InsertedEf { ef; k=n.k } *\) *)
(*   (\*   | Too_far, Inserted k -> InsertedNotEf { ef=n.ef; k } *\) *)

(*   let fold_ef n ~init ~f = *)
(*     N.fold n.ef ~init ~f *)
(*   let fold_ef_distance n ~init ~f = *)
(*     N.fold_distance n.ef ~init ~f *)
(*   let max_distance_ef n = *)
(*     N.max_distance n.ef *)
(*   let nearest_k n = *)
(*     N.fold_far_to_near n.k ~init:[] ~f:(fun acc e -> e::acc) *)
(* end *)

module VisitMe(Distance : DISTANCE)(Value : Hnsw_algo.VALUE with type value = Distance.value) = struct
  (* module Hgraph = HgraphIncr(Distance) *)
  module Nearest = Nearest(Distance)(Value)
  module MinHeap = Hnsw_algo.MinHeap(Distance)(Value)
  type t_value_computer = Value.t (* [@@deriving sexp] *)
  type value = Value.value [@@deriving sexp]
  type t = { target : value;
             value_computer : t_value_computer sexp_opaque;
             heap : MinHeap.t } [@@deriving sexp]
  type node = Value.node
  type nearest = Nearest.t

  let singleton value_computer target element =
    { target; value_computer;
      heap = MinHeap.singleton element } (* (MinHeap.Element.of_node target value_computer n) } *)

  let of_nearest nearest =
    { target = Nearest.target nearest;
      value_computer = Nearest.value_computer nearest;
      heap = Nearest.fold_distance nearest ~init:(MinHeap.create ()) ~f:(fun h e ->
          MinHeap.add h { node = e.node; distance_to_target = e.distance_to_target }) }
  let nearest (v : t) =
    match MinHeap.min v.heap with
    | None -> None
    | Some node -> Some node.node
  let pop_nearest (v : t) =
    match MinHeap.pop_min v.heap with
    | None -> None
    | Some (n, h) -> Some (n, { v with heap = h })
  (* let add (v : t) node = *)
  (*   { v with heap = MinHeap.add v.heap (MinHeap.Element.of_node v.target v.value_computer node) } *)
  let add_distance (v : t) (element : node value_distance) =
    { v with heap = MinHeap.add v.heap element }
  let fold v ~init ~f =
    MinHeap.fold v.heap ~init ~f:(fun acc (element : _ Hnsw_algo.value_distance) -> f acc element.node)
end

(* module EuclideanDistanceArray = struct *)
(*   type value = float array [@@deriving sexp] *)
(*   let distance (a : value) (b : value) = *)
(*     if Array.length a <> Array.length b then *)
(*       raise (Invalid_argument "distance: arrays with different lengths"); *)
(*     let ret = ref 0. in *)
(*     for i = 0 to Array.length a - 1 do *)
(*       let diff = a.(i) -. b.(i) in *)
(*       ret := !ret +. diff *. diff *)
(*     done; *)
(*     Float.sqrt(!ret) *)
(* end *)

(* module HgraphEuclideanArray = Hgraph(EuclideanDistanceArray) *)
(* module BuildArray = Hnsw_algo.Build *)
(*     (HgraphEuclideanArray) *)
(*     (VisitMe(EuclideanDistanceArray)) *)
(*     (Nearest(EuclideanDistanceArray)) *)
(*     (EuclideanDistanceArray) *)

(*
    level_mult = 1 / log(M)

    M_max_0 = 2 * M
    they have M_max for layers > 0 and M_max_0 for layer 0
    nmslib sets M_max = M.
    M_max is Hgraph.max_num_neighbours

    M in 5..48 (higher: for higher dim, higher recall, drives memory consumption)
    M == num_neighbours passed to Build.insert and Build.create
    It is the number of neighbours one selects when inserting one
    given point. If adding these neighbours makes one node's
    neighbours be more than M_max, the neighbours are truncated.

    efConstruction can be autoconfigured (how ?), gives example of
    100, should allow high recall (0.95) during construction
    efConstruction == num_neighbours_search passed to Build.insert and Build.create
    This is set to 200 or 400 in the ann benchmark.

    ef used during search only on layer 0
    Currently ef == num_neighbours + num_additional_neighbours_search in Search.search and Knn.knn
    Not clear how to configure. I suppose having it in 0..~M is reasonable.
    Note that ATM we need ef > k for our implementation to work, which is a shame: it limits
    how fast it can go.

    TODO: look at code and benchmarks, see how they configure ef and efConstruction and M.
 *)
(* let build_array fold_data = *)
(*   let num_neighbours = 3 in *)
(*   let max_num_neighbours = 2 * num_neighbours in *)
(*   let num_neighbours_search = 7 in *)
(*   let level_mult = 1. /. Float.log (Float.of_int num_neighbours) in *)
(*   BuildArray.create fold_data *)
(*     ~num_neighbours ~max_num_neighbours ~num_neighbours_search ~level_mult *)

(* module KnnArray = Hnsw_algo.Knn *)
(*     (HgraphEuclideanArray) *)
(*     (VisitMe(EuclideanDistanceArray)) *)
(*     (Nearest(EuclideanDistanceArray)) *)
(*     (EuclideanDistanceArray) *)

(* let knn_array hgraph point num_neighbours = *)
(*   let num_additional_neighbours_search = 1 in *)
(*   KnnArray.knn hgraph point ~num_neighbours ~num_additional_neighbours_search *)

(* module HgraphEuclideanBigarray = Hgraph(EuclideanDistanceBigarray) *)
(* module BuildBigarray = Hnsw_algo.Build *)
(*     (HgraphEuclideanBigarray) *)
(*     (VisitMe(EuclideanDistanceBigarray)) *)
(*     (Nearest(EuclideanDistanceBigarray)) *)
(*     (EuclideanDistanceBigarray) *)

(* let build_bigarray ?(num_neighbours=5) ?(num_neighbours_build=10) fold_data = *)
(*   let max_num_neighbours = 2 * num_neighbours in *)
(*   let level_mult = 1. /. Float.log (Float.of_int num_neighbours) in *)
(*   BuildBigarray.create fold_data *)
(*     ~num_neighbours ~max_num_neighbours ~num_neighbours_search:num_neighbours_build ~level_mult *)

(* module KnnBigarray = Hnsw_algo.Knn *)
(*     (HgraphEuclideanBigarray) *)
(*     (VisitMe(EuclideanDistanceBigarray)) *)
(*     (Nearest(EuclideanDistanceBigarray)) *)
(*     (EuclideanDistanceBigarray) *)

(* let knn_bigarray hgraph point ?(num_additional_neighbours_search=0) num_neighbours = *)
(*   KnnBigarray.knn hgraph point ~num_neighbours ~num_additional_neighbours_search *)

(* XXX TODO: make the user instantiate one simple functor instead of
   this copy-paste madness *)
(*  potential speedups:
    - get values from a bigarray instead of a map
*)

module MakeSimple(Distance : DISTANCE) = struct
  module Hgraph = HgraphIncr(Distance)
  module VisitMe = VisitMe(Distance)(Hgraph)
  module Nearest = Nearest(Distance)(Hgraph)
  module Build = Hnsw_algo.BuildIncr(Hgraph)(VisitMe)(Nearest)(Distance)
  module Knn = Hnsw_algo.Knn(Hgraph)(VisitMe)(Nearest)(Distance)

  type t = Hgraph.t
  type value = Distance.value

  let build ~num_neighbours ~num_neighbours_build fold_rows =
    let max_num_neighbours0 = 2 * num_neighbours in
    let level_mult = 1. /. Float.log (Float.of_int num_neighbours) in
    Build.create fold_rows
      ~num_neighbours ~max_num_neighbours:num_neighbours ~max_num_neighbours0
      ~num_neighbours_search:num_neighbours_build ~level_mult

  let knn (hgraph : t) (point : value) ~num_neighbours_search ~num_neighbours =
    Knn.knn hgraph point ~num_neighbours ~num_neighbours_search
end

module MakeBatch(Distance : DISTANCE with type value = Lacaml.S.vec) = struct
  module Distance = struct
    type value = Distance.value [@@deriving sexp]
    let num_calls = ref 0
    let distance a b =
      Int.incr num_calls;
      Distance.distance a b
  end
  module Hgraph = HgraphBatch(Distance)
  module VisitMe = VisitMe(Distance)(Hgraph)
  module Nearest = Nearest(Distance)(Hgraph)
  module Build = Hnsw_algo.BuildBatch(Hgraph)(VisitMe)(Nearest)(Distance)
  module Knn = Hnsw_algo.Knn(Hgraph)(VisitMe)(Nearest)(Distance)

  type t = Hgraph.t
  type value = Distance.value

  let count_distance name f =
    let n0 = !Distance.num_calls in
    let ret = f () in
    let dn = !Distance.num_calls - n0 in
    printf "%s: %d distance computations\n" name dn;
    ret
  
  let build ~num_neighbours ~num_neighbours_build values =
    let max_num_neighbours0 = 2 * num_neighbours in
    let level_mult = 1. /. Float.log (Float.of_int num_neighbours) in
    Build.create values
      ~num_neighbours ~max_num_neighbours:num_neighbours ~max_num_neighbours0
      ~num_neighbours_search:num_neighbours_build ~level_mult

  let build ~num_neighbours ~num_neighbours_build values =
    count_distance "build" (fun () -> build ~num_neighbours ~num_neighbours_build values)
  
  let knn (hgraph : t) (point : value) ~num_neighbours_search ~num_neighbours =
    Knn.knn hgraph point ~num_neighbours ~num_neighbours_search

  let knn (hgraph : t) (point : value) ~num_neighbours_search ~num_neighbours =
    count_distance "knn" (fun () -> knn hgraph point ~num_neighbours_search ~num_neighbours)
  
  let knn_batch hgraph batch ~num_neighbours_search ~num_neighbours =
    let distances = Lacaml.S.Mat.create num_neighbours (Lacaml.S.Mat.dim2 batch) in
    Lacaml.S.Mat.fill distances Float.infinity;
    let _ = Hgraph.Values.foldi batch ~init:() ~f:(fun () j row ->
        let neighbours = knn hgraph row ~num_neighbours_search ~num_neighbours in
        List.iteri neighbours ~f:(fun i { Hnsw_algo.distance_to_target; _ } ->
            distances.{i+1, j} <- distance_to_target))
    in
    distances
end


module type BATCH = sig
  include DISTANCE
  type t
  val fold : t -> init:'acc -> f:('acc -> value -> 'acc) -> 'acc
  val length : t -> int
  module Distances : sig
    type t
    val create : len_batch:int -> num_neighbours:int -> t
    (*  this element list type is ugly, pull it out  *)
    val set : t -> int -> _ Hnsw_algo.value_distance list -> unit
  end
end

module Make(Batch : BATCH) = struct
  include MakeSimple(Batch)

  let build_batch ~num_neighbours ~num_neighbours_build data =
    build ~num_neighbours ~num_neighbours_build (Batch.fold data)

  let knn_batch hgraph batch ~num_neighbours_search ~num_neighbours =
    let distances = Batch.Distances.create ~len_batch:(Batch.length batch) ~num_neighbours in
    let _ = Batch.fold batch ~init:1 ~f:(fun i row ->
        let neighbours = knn hgraph row ~num_neighbours_search ~num_neighbours in
        Batch.Distances.set distances i neighbours;
        i + 1) in
    distances
end

module EuclideanBa = struct
  type value = Lacaml.S.vec sexp_opaque [@@deriving sexp]
  (* we would be fine doing all intermediary computations in squared
     distances, but in the end we need to return proper L2 distances to
     the user; atm it is simpler to just use sqrt here *)
  let distance a b = Float.sqrt @@ Lacaml.S.Vec.ssqr_diff a b
end

module BatchEuclidean = MakeBatch(EuclideanBa)

module Ba = BatchEuclidean
(* struct *)
(*   module Batch = struct *)
(*     type value = Lacaml.S.vec (\* (float, Bigarray.float32_elt, Bigarray.c_layout) Bigarray.Array1.t *\) *)
(*     type t = Lacaml.S.mat *)
(*     let list_of_bigarray v = *)
(*       let acc = ref [] in *)
(*       for i = 1 to Bigarray.Array1.dim v do *)
(*         acc := v.{i}::!acc *)
(*       done; *)
(*       List.rev !acc *)
(*     let sexp_of_value v = Sexp.List (List.map ~f:(fun e -> Sexp.Atom (Float.to_string e)) (list_of_bigarray v)) *)
(*     let value_of_sexp s = invalid_arg "EuclideanDistanceBigarray.value_of_sexp: not implemented" *)
(*     let distance (a : value) (b : value) = *)
(*       Float.sqrt @@ Lacaml.S.Vec.ssqr_diff a b *)

(*     let fold ba ~init ~f = *)
(*       let n = Bigarray.Array2.dim2 ba in *)
(*       let k_print = max (n / 100) 1 in *)
(*       let acc = ref init in *)
(*       for i = 1 to n do *)
(*         if i % k_print = 0 then begin *)
(*           printf "\r              \r%d/%d %d%%%!" i n *)
(*             (Int.of_float (100. *. Float.of_int i /. Float.of_int n)); *)
(*         end; *)
(*         let row = Lacaml.S.Mat.col ba i in *)
(*         acc := f !acc row *)
(*       done; *)
(*       printf "\n"; *)
(*       !acc *)

(*     let length ba = Lacaml.S.Mat.dim2 ba *)
(*     module Distances = struct *)
(*       type t = Lacaml.S.Mat.t *)
(*       let create ~len_batch ~num_neighbours = Lacaml.S.Mat.create num_neighbours len_batch *)
(*       let set mat j neighbours = *)
(*         List.iteri neighbours ~f:(fun i { Hnsw_algo.distance_to_target; _ } -> *)
(*             mat.{i+1, j} <- distance_to_target) *)
(*     end *)
(*   end *)
(*   include Make(Batch) *)
(* end *)

(*  TODO:
    DONE create HgraphBatch
    - create MakeBatch
    - make Ba use MakeBatch instead of MakeSimple
*)
module Ohnsw = Ohnsw
