(************************************************************************)
(*         *   The Coq Proof Assistant / The Coq Development Team       *)
(*  v      *         Copyright INRIA, CNRS and contributors             *)
(* <O___,, * (see version control and CREDITS file for authors & dates) *)
(*   \VV/  **************************************************************)
(*    //   *    This file is distributed under the terms of the         *)
(*         *     GNU Lesser General Public License Version 2.1          *)
(*         *     (see LICENSE file for the text of the license)         *)
(************************************************************************)

open Names
open Constr
open Entries

(** This module provides the official functions to declare new
   variables, parameters, constants and inductive types in the global
   environment. It also updates some accesory tables such as [Nametab]
   (name resolution), [Impargs], and [Notations]. *)

(** We provide two kind of fuctions:

  - one go functions, that will register a constant in one go, suited
   for non-interactive definitions where the term is given.

  - two-phase [start/declare] functions which will create an
   interactive proof, allow its modification, and saving when
   complete.

  Internally, these functions mainly differ in that usually, the first
  case doesn't require setting up the tactic engine.

 *)

(** [Declare.Proof.t] Construction of constants using interactive proofs. *)
module Proof : sig

  type t

  (** XXX: These are internal and will go away from publis API once
     lemmas is merged here *)
  val get_proof : t -> Proof.t
  val get_proof_name : t -> Names.Id.t

  (** XXX: These 3 are only used in lemmas  *)
  val get_used_variables : t -> Names.Id.Set.t option
  val get_universe_decl : t -> UState.universe_decl
  val get_initial_euctx : t -> UState.t

  val map_proof : (Proof.t -> Proof.t) -> t -> t
  val map_fold_proof : (Proof.t -> Proof.t * 'a) -> t -> t * 'a
  val map_fold_proof_endline : (unit Proofview.tactic -> Proof.t -> Proof.t * 'a) -> t -> t * 'a

  (** Sets the tactic to be used when a tactic line is closed with [...] *)
  val set_endline_tactic : Genarg.glob_generic_argument -> t -> t

  (** Sets the section variables assumed by the proof, returns its closure
   * (w.r.t. type dependencies and let-ins covered by it) *)
  val set_used_variables : t ->
    Names.Id.t list -> Constr.named_context * t

  val compact : t -> t

  (** Update the proofs global environment after a side-effecting command
      (e.g. a sublemma definition) has been run inside it. Assumes
      there_are_pending_proofs. *)
  val update_global_env : t -> t

  val get_open_goals : t -> int

end

type opacity_flag = Opaque | Transparent

(** [start_proof ~name ~udecl ~poly sigma goals] starts a proof of
   name [name] with goals [goals] (a list of pairs of environment and
   conclusion); [poly] determines if the proof is universe
   polymorphic. The proof is started in the evar map [sigma] (which
   can typically contain universe constraints), and with universe
   bindings [udecl]. *)
val start_proof
  :  name:Names.Id.t
  -> udecl:UState.universe_decl
  -> poly:bool
  -> Evd.evar_map
  -> (Environ.env * EConstr.types) list
  -> Proof.t

(** Like [start_proof] except that there may be dependencies between
    initial goals. *)
val start_dependent_proof
  :  name:Names.Id.t
  -> udecl:UState.universe_decl
  -> poly:bool
  -> Proofview.telescope
  -> Proof.t

(** Proof entries represent a proof that has been finished, but still
   not registered with the kernel.

   XXX: Scheduled for removal from public API, don't rely on it *)
type 'a proof_entry = private {
  proof_entry_body   : 'a Entries.const_entry_body;
  (* List of section variables *)
  proof_entry_secctx : Id.Set.t option;
  (* State id on which the completion of type checking is reported *)
  proof_entry_feedback : Stateid.t option;
  proof_entry_type        : Constr.types option;
  proof_entry_universes   : Entries.universes_entry;
  proof_entry_opaque      : bool;
  proof_entry_inline_code : bool;
}

(** XXX: Scheduled for removal from public API, don't rely on it *)
type proof_object = private
  { name : Names.Id.t
  (** name of the proof *)
  ; entries : Evd.side_effects proof_entry list
  (** list of the proof terms (in a form suitable for definitions). *)
  ; uctx: UState.t
  (** universe state *)
  }

val close_proof : opaque:opacity_flag -> keep_body_ucst_separate:bool -> Proof.t -> proof_object

(** Declaration of local constructions (Variable/Hypothesis/Local) *)

(** XXX: Scheduled for removal from public API, don't rely on it *)
type variable_declaration =
  | SectionLocalDef of Evd.side_effects proof_entry
  | SectionLocalAssum of { typ:types; impl:Glob_term.binding_kind; }

(** XXX: Scheduled for removal from public API, don't rely on it *)
type 'a constant_entry =
  | DefinitionEntry of 'a proof_entry
  | ParameterEntry of parameter_entry
  | PrimitiveEntry of primitive_entry

val declare_universe_context : poly:bool -> Univ.ContextSet.t -> unit

val declare_variable
  :  name:variable
  -> kind:Decls.logical_kind
  -> variable_declaration
  -> unit

(** Declaration of global constructions
   i.e. Definition/Theorem/Axiom/Parameter/...

   XXX: Scheduled for removal from public API, use `DeclareDef` instead *)
val definition_entry
  : ?fix_exn:Future.fix_exn
  -> ?opaque:bool
  -> ?inline:bool
  -> ?feedback_id:Stateid.t
  -> ?section_vars:Id.Set.t
  -> ?types:types
  -> ?univs:Entries.universes_entry
  -> ?eff:Evd.side_effects
  -> ?univsbody:Univ.ContextSet.t
  (** Universe-constraints attached to the body-only, used in
     vio-delayed opaque constants and private poly universes *)
  -> constr
  -> Evd.side_effects proof_entry

(** XXX: Scheduled for removal from public API, use `DeclareDef` instead *)
val pure_definition_entry
  : ?fix_exn:Future.fix_exn
  -> ?opaque:bool
  -> ?inline:bool
  -> ?types:types
  -> ?univs:Entries.universes_entry
  -> constr
  -> unit proof_entry

type import_status = ImportDefaultBehavior | ImportNeedQualified

(** [declare_constant id cd] declares a global declaration
   (constant/parameter) with name [id] in the current section; it returns
   the full path of the declaration

  internal specify if the constant has been created by the kernel or by the
  user, and in the former case, if its errors should be silent

  XXX: Scheduled for removal from public API, use `DeclareDef` instead *)
val declare_constant
  :  ?local:import_status
  -> name:Id.t
  -> kind:Decls.logical_kind
  -> Evd.side_effects constant_entry
  -> Constant.t

val declare_private_constant
  :  ?role:Evd.side_effect_role
  -> ?local:import_status
  -> name:Id.t
  -> kind:Decls.logical_kind
  -> unit proof_entry
  -> Constant.t * Evd.side_effects

(** [inline_private_constants ~sideff ~uctx env ce] will inline the
   constants in [ce]'s body and return the body plus the updated
   [UState.t].

   XXX: Scheduled for removal from public API, don't rely on it *)
val inline_private_constants
  :  uctx:UState.t
  -> Environ.env
  -> Evd.side_effects proof_entry
  -> Constr.t * UState.t

(** Declaration messages *)

(** XXX: Scheduled for removal from public API, do not use *)
val definition_message : Id.t -> unit
val assumption_message : Id.t -> unit
val fixpoint_message : int array option -> Id.t list -> unit
val recursive_message : bool (** true = fixpoint *) ->
  int array option -> Id.t list -> unit

val check_exists : Id.t -> unit

(* Used outside this module only in indschemes *)
exception AlreadyDeclared of (string option * Id.t)

(** {6 For legacy support, do not use}  *)

module Internal : sig

  val map_entry_body : f:('a Entries.proof_output -> 'b Entries.proof_output) -> 'a proof_entry -> 'b proof_entry
  val map_entry_type : f:(Constr.t option -> Constr.t option) -> 'a proof_entry -> 'a proof_entry
  (* Overriding opacity is indeed really hacky *)
  val set_opacity : opaque:bool -> 'a proof_entry -> 'a proof_entry

  (* TODO: This is only used in DeclareDef to forward the fix to
     hooks, should eventually go away *)
  val get_fix_exn : 'a proof_entry -> Future.fix_exn

  val shrink_entry : EConstr.named_context -> 'a proof_entry -> 'a proof_entry * Constr.constr list

  type constant_obj

  val objConstant : constant_obj Libobject.Dyn.tag
  val objVariable : unit Libobject.Dyn.tag

end

(* Intermediate step necessary to delegate the future.
 * Both access the current proof state. The former is supposed to be
 * chained with a computation that completed the proof *)
type closed_proof_output

(** Requires a complete proof. *)
val return_proof : Proof.t -> closed_proof_output

(** An incomplete proof is allowed (no error), and a warn is given if
   the proof is complete. *)
val return_partial_proof : Proof.t -> closed_proof_output
val close_future_proof : feedback_id:Stateid.t -> Proof.t -> closed_proof_output Future.computation -> proof_object

(** [by tac] applies tactic [tac] to the 1st subgoal of the current
    focused proof.
    Returns [false] if an unsafe tactic has been used. *)
val by : unit Proofview.tactic -> Proof.t -> Proof.t * bool

(** Declare abstract constant; will check no evars are possible; *)
val declare_abstract :
     name:Names.Id.t
  -> poly:bool
  -> kind:Decls.logical_kind
  -> sign:EConstr.named_context
  -> secsign:Environ.named_context_val
  -> opaque:bool
  -> solve_tac:unit Proofview.tactic
  -> Evd.evar_map
  -> EConstr.t
  -> Evd.side_effects * Evd.evar_map * EConstr.t * EConstr.t list * bool

val build_by_tactic
  :  ?side_eff:bool
  -> Environ.env
  -> uctx:UState.t
  -> poly:bool
  -> typ:EConstr.types
  -> unit Proofview.tactic
  -> Constr.constr * Constr.types option * bool * UState.t

(** {6 Helpers to obtain proof state when in an interactive proof } *)

(** [get_goal_context n] returns the context of the [n]th subgoal of
   the current focused proof or raises a [UserError] if there is no
   focused proof or if there is no more subgoals *)

val get_goal_context : Proof.t -> int -> Evd.evar_map * Environ.env

(** [get_current_goal_context ()] works as [get_goal_context 1] *)
val get_current_goal_context : Proof.t -> Evd.evar_map * Environ.env

(** [get_current_context ()] returns the context of the
  current focused goal. If there is no focused goal but there
  is a proof in progress, it returns the corresponding evar_map.
  If there is no pending proof then it returns the current global
  environment and empty evar_map. *)
val get_current_context : Proof.t -> Evd.evar_map * Environ.env
