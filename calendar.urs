(* An extensible calendar: different program modules may contribute different sorts of events *)

(* Generators of calendar entries *)
con t :: {Type}    (* Dictionary of all key fields used across all sources of events *)
         -> {(Type * Type * Type)} (* Mapping user-meaningful tags (for event kinds) to associated data
                                    * and the way to encode it imperatively with client-side widgets *)
         -> Type

(* Levels of access control *)
datatype level = Forbidden | Read | Write

functor FromTable(M : sig
                      con tag :: Name
                      con key :: {(Type * Type * Type)} (* Each 2nd component is a type of GUI widget private state. *)
                      con times :: {Unit}
                      con other :: {(Type * Type * Type)}
                      con us :: {{Unit}}
                      constraint key ~ times
                      constraint key ~ other
                      constraint times ~ other
                      constraint [When, Kind, ShowTime] ~ key
                      val fl : folder key
                      val flO : folder other
                      val flT : folder times
                      val inj : $(map (fn p => sql_injectable_prim p.1) key)
                      val injO : $(map (fn p => sql_injectable p.1) other)
                      val ws : $(map Widget.t' (key ++ other))
                      val tab : sql_table (map fst3 (key ++ other) ++ mapU time times) us
                      val labels : $(map (fn _ => string) (key ++ other) ++ mapU string times)
                      val eqs : $(map (fn p => eq p.1) key)
                      val title : string
                      val display : option (Ui.context -> $(map fst3 key) -> transaction xbody)
                      val auth : transaction level
                      val showTime : bool (* If [False], then only associate events with days. *)
                      val kinds : $(mapU string times)
                      val sh : show $(map fst3 key)
                  end) : sig
    con private :: (Type * Type * Type)
    con tag = M.tag
    val cal : t (map fst3 M.key) [tag = private]
end

val compose : keys1 ::: {Type} -> keys2 ::: {Type}
              -> tags1 ::: {(Type * Type * Type)} -> tags2 ::: {(Type * Type * Type)}
              -> [keys1 ~ keys2] => [tags1 ~ tags2]
              => folder keys1 -> folder keys2
              -> $(map sql_injectable_prim keys1)
              -> $(map sql_injectable_prim keys2)
              -> t keys1 tags1 -> t keys2 tags2 -> t (keys1 ++ keys2) (tags1 ++ tags2)

functor Make(M : sig
                 con keys :: {Type}
                 con tags :: {(Type * Type * Type)}
                 constraint [When, Kind, ShowTime] ~ keys
                 val t : t keys tags
                 val fl : folder tags
             end) : Ui.S where type input = {FromDay : time,
                                             ToDay : time} (* inclusive *)
