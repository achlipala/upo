(* A configurable way of listing table rows as HTML tables *)

con t :: Type (* arbitrary input value, to use for filtering *)
    -> {Type} (* available columns of table we are listing *)
    -> Type   (* configuration, to prepare once on server *)
    -> Type   (* internal type for server-generated data to render locally *)
    -> Type

val compose : inp ::: Type -> r ::: {Type} -> cfga ::: Type -> cfgb ::: Type
              -> sta ::: Type -> stb ::: Type
              -> t inp r cfga sta -> t inp r cfgb stb -> t inp r (cfga * cfgb) (sta * stb)

type inputIs_cfg
type inputIs_st
val inputIs : inp ::: Type -> col :: Name -> r ::: {Type} -> [[col] ~ r]
              => sql_injectable inp
              -> t inp ([col = inp] ++ r) inputIs_cfg inputIs_st

type inputIsOpt_cfg
type inputIsOpt_st
val inputIsOpt : inp ::: Type -> col :: Name -> r ::: {Type} -> [[col] ~ r]
                 => sql_injectable_prim inp
                 -> t inp ([col = option inp] ++ r) inputIs_cfg inputIs_st

con column_cfg :: Type -> Type
con column_st :: Type -> Type
val column : inp ::: Type -> col :: Name -> colT ::: Type -> r ::: {Type} -> [[col] ~ r]
             => show colT
             -> string (* label *)
             -> t inp ([col = colT] ++ r) (column_cfg colT) (column_st colT)

type html_cfg
type html_st
val html : inp ::: Type -> col :: Name -> r ::: {Type} -> [[col] ~ r]
           => string (* label *)
           -> t inp ([col = string] ++ r) html_cfg html_st

con iconButton_cfg :: {Type} -> Type
con iconButton_st :: {Type} -> Type
val iconButton : inp ::: Type -> cols ::: {Type} -> r ::: {Type} -> [cols ~ r]
                 => transaction (option string) (* get username, if any *)
                 -> (option string (* username, if any *)
                     -> time       (* very recent timestamp *)
                     -> $cols      (* values of selected columns *)
                     -> option (css_class (* choose a Font Awesome icon *)
                                * url     (* ...and where clicking should take you *)))
                 -> string (* label *)
                 -> t inp (cols ++ r) (iconButton_cfg cols) (iconButton_st cols)

con linked_cfg :: Type -> Type
con linked_st :: Type -> Type
val linked : inp ::: Type -> this :: Name -> fthis :: Name -> thisT ::: Type
             -> fthat :: Name -> thatT ::: Type
             -> r ::: {Type} -> fr ::: {Type} -> ks ::: {{Unit}}
             -> [[this] ~ r] => [[fthis] ~ [fthat]] => [[fthis, fthat] ~ fr]
             => show thatT -> sql_injectable thisT
             -> sql_table ([fthis = thisT, fthat = thatT] ++ fr) ks
             -> string (* label *)
             -> t inp ([this = thisT] ++ r) (linked_cfg thatT) (linked_st thatT)

con orderedLinked_cfg :: Type -> Type
con orderedLinked_st :: Type -> Type
val orderedLinked : inp ::: Type -> this :: Name -> fthis :: Name -> thisT ::: Type
                    -> fthat :: Name -> thatT ::: Type
                    -> r ::: {Type} -> fr ::: {Type} -> ks ::: {{Unit}}
                    -> [[this] ~ r] => [[fthis] ~ [fthat]] => [[fthis, fthat] ~ [SeqNum]] => [[fthis, fthat, SeqNum] ~ fr]
                    => show thatT -> sql_injectable thisT
                    -> sql_table ([fthis = thisT, fthat = thatT, SeqNum = int] ++ fr) ks
                    -> string (* label *)
                    -> t inp ([this = thisT] ++ r) (orderedLinked_cfg thatT) (orderedLinked_st thatT)

functor LinkedWithEdit(M : sig
                           type inp
                           con this :: Name
                           con fthis :: Name
                           con thisT :: Type
                           con fthat :: Name
                           con thatT :: Type
                           con r :: {Type}
                           constraint [this] ~ r
                           constraint [fthis] ~ [fthat]
                           val show_that : show thatT
                           val read_that : read thatT
                           val eq_that : eq thatT
                           val inj_this : sql_injectable thisT
                           val inj_that : sql_injectable thatT
                           table link : {fthis : thisT, fthat : thatT}

                           con tkey :: Name
                           con tr :: {Type}
                           constraint [tkey] ~ tr
                           table that : ([tkey = thatT] ++ tr)

                           val label : string
                           val authorized : transaction bool
                       end) : sig
    type cfg
    type internal
    val t : t M.inp ([M.this = M.thisT] ++ M.r) cfg internal
end

functor LinkedWithFollow(M : sig
                             type inp
                             con this :: Name
                             con fthis :: Name
                             con thisT :: Type
                             con fthat :: Name
                             con thatT :: Type
                             con r :: {Type}
                             constraint [this] ~ r
                             constraint [fthis] ~ [fthat]
                             val show_that : show thatT
                             val inj_this : sql_injectable thisT
                             val inj_that : sql_injectable thatT
                             table from : {fthis : thisT, fthat : thatT}

                             con user :: Name
                             con cthat :: Name
                             constraint [user] ~ [cthat]
                             table to : {user : string, cthat : thatT}

                             val label : string
                             val whoami : transaction (option string)
                         end) : sig
    type cfg
    type internal
    val t : t M.inp ([M.this = M.thisT] ++ M.r) cfg internal
end

(* Indicate interest in the current item. *)
functor Like(M : sig
                 type inp
                 con this :: Name
                 con fthis :: Name
                 con thisT :: Type
                 con user :: Name
                 con r :: {Type}
                 constraint [this] ~ r
                 constraint [fthis] ~ [user]
                 val inj_this : sql_injectable thisT
                 table like : {fthis : thisT, user : string}

                 val label : string
                 val whoami : transaction (option string)
             end) : sig
    type cfg
    type internal
    val t : t M.inp ([M.this = M.thisT] ++ M.r) cfg internal
end

(* Like [Like], but with an additional option to indicate preferred choices *)
functor Bid(M : sig
                type inp
                con this :: Name
                con fthis :: Name
                con thisT :: Type
                con user :: Name
                con preferred :: Name
                con r :: {Type}
                constraint [this] ~ r
                constraint [fthis] ~ [user]
                constraint [fthis, user] ~ [preferred]
                val inj_this : sql_injectable thisT
                table bid : {fthis : thisT, user : string, preferred : bool}

                val label : string
                val whoami : transaction (option string)
            end) : sig
    type cfg
    type internal
    val t : t M.inp ([M.this = M.thisT] ++ M.r) cfg internal
end

(* Now an admin can use those bids to assign users to items. *)
functor AssignFromBids(M : sig
                           type inp
                           con this :: Name
                           con assignee :: Name
                           con fthis :: Name
                           con thisT :: Type
                           con user :: Name
                           con preferred :: Name
                           con r :: {Type}
                           constraint [this] ~ [assignee]
                           constraint [this, assignee] ~ r
                           constraint [fthis] ~ [user]
                           constraint [fthis, user] ~ [preferred]
                           val inj_this : sql_injectable thisT
                           table bid : {fthis : thisT, user : string, preferred : bool}

                           val label : string
                           val whoami : transaction (option string)

                           table tab : ([this = thisT, assignee = option string] ++ r)
                       end) : sig
    type cfg
    type internal
    val t : t M.inp ([M.this = M.thisT, M.assignee = option string] ++ M.r) cfg internal
end

(* Variant: we have assigned some users, who gave their preferences for another aspect (e.g. times).
 * Now assign a value for that aspect, based on preferences of assigned users. *)
functor AssignFromBids2(M : sig
                            type inp
                            con fthat :: Name
                            con thatT :: Type
                            con user :: Name
                            con preferred :: Name
                            constraint [fthat] ~ [user]
                            constraint [fthat, user] ~ [preferred]
                            table bid : {fthat : thatT, user : string, preferred : bool}

                            con this :: Name
                            con thisT :: Type
                            con that :: Name
                            con assignees :: {Unit}
                            con r :: {Type}
                            constraint [this] ~ [that]
                            constraint [this, that] ~ assignees
                            constraint [this, that] ~ r
                            constraint assignees ~ r
                            table tab : ([this = thisT, that = option thatT] ++ mapU (option string) assignees ++ r)

                            val fl : folder assignees
                            val show_that : show thatT
                            val read_that : read thatT
                            val eq_that : eq thatT
                            val inj_that : sql_injectable_prim thatT
                            val inj_this : sql_injectable thisT

                            val label : string
                            val whoami : transaction (option string)
                        end) : sig
    type cfg
    type internal
    val t : t M.inp ([M.this = M.thisT, M.that = option M.thatT] ++ mapU (option string) M.assignees ++ M.r) cfg internal
end

type nonnull_cfg
type nonnull_st
val nonnull : inp ::: Type -> col :: Name -> ct ::: Type -> r ::: {Type} -> [[col] ~ r]
              => t inp ([col = option ct] ++ r) nonnull_cfg nonnull_st
type isnull_cfg
type isnull_st
val isnull : inp ::: Type -> col :: Name -> ct ::: Type -> r ::: {Type} -> [[col] ~ r]
              => t inp ([col = option ct] ++ r) isnull_cfg isnull_st

type taggedWithUser_cfg
type taggedWithUser_st
val taggedWithUser : inp ::: Type -> user :: Name -> r ::: {Type} -> [[user] ~ r]
                   => transaction (option string) (* get username, if any *)
                   -> t inp ([user = string] ++ r) taggedWithUser_cfg taggedWithUser_st

type linkedToUser_cfg
type linkedToUser_st
val linkedToUser : inp ::: Type -> key :: Name -> keyT ::: Type -> r ::: {Type} -> [[key] ~ r]
                   => ckey :: Name -> user :: Name -> cr ::: {Type} -> ks ::: {{Unit}} -> [[ckey] ~ [user]] => [[ckey, user] ~ cr]
                   => sql_table ([ckey = keyT, user = string] ++ cr) ks (* connector that must link current user to row *)
                   -> transaction (option string) (* get username, if any *)
                   -> t inp ([key = keyT] ++ r) linkedToUser_cfg linkedToUser_st

type doubleLinkedToUser_cfg
type doubleLinkedToUser_st
val doubleLinkedToUser : inp ::: Type -> key :: Name -> keyT ::: Type -> r ::: {Type} -> [[key] ~ r]
                         => ckey :: Name -> ikey :: Name -> ikeyT ::: Type -> cr1 ::: {Type} -> ks1 ::: {{Unit}} -> [[ckey] ~ [ikey]] => [[ckey, ikey] ~ cr1]
                         => ikey2 :: Name -> user :: Name -> cr2 ::: {Type} -> ks2 ::: {{Unit}} -> [[ikey2] ~ [user]] => [[ikey2, user] ~ cr2]
                         => sql_table ([ckey = keyT, ikey = ikeyT] ++ cr1) ks1
                         -> sql_table ([ikey2 = ikeyT, user = string] ++ cr2) ks2
                         -> transaction (option string) (* get username, if any *)
                         -> t inp ([key = keyT] ++ r) doubleLinkedToUser_cfg doubleLinkedToUser_st

type sortby_cfg
type sortby_st
val sortby : inp ::: Type -> col :: Name -> ct ::: Type -> r ::: {Type} -> [[col] ~ r]
             => t inp ([col = ct] ++ r) sortby_cfg sortby_st
val sortbyDesc : inp ::: Type -> col :: Name -> ct ::: Type -> r ::: {Type} -> [[col] ~ r]
                 => t inp ([col = ct] ++ r) sortby_cfg sortby_st

functor Make(M : sig
                 con r :: {(Type * Type * Type)}
                 table tab : (map fst3 r)

                 type cfg
                 type st
                 val t : t unit (map fst3 r) cfg st
                 val widgets : $(map Widget.t' r)
                 val fl : folder r
                 val labels : $(map (fn _ => string) r)
                 val injs : $(map (fn p => sql_injectable p.1) r)

                 val authorized : transaction bool
                 val allowCreate : bool
             end) : Ui.S0

(* This version expects an explicit input. *)
functor Make1(M : sig
                  type inp
                  con r :: {(Type * Type * Type)}
                  table tab : (map fst3 r)

                  type cfg
                  type st
                  val t : t inp (map fst3 r) cfg st
                  val widgets : $(map Widget.t' r)
                  val fl : folder r
                  val labels : $(map (fn _ => string) r)
                  val injs : $(map (fn p => sql_injectable p.1) r)

                  val authorized : transaction bool
                  val allowCreate : bool
              end) : Ui.S where type input = M.inp