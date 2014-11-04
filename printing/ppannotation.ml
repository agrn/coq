(************************************************************************)
(*  v      *   The Coq Proof Assistant  /  The Coq Development Team     *)
(* <O___,, *   INRIA - CNRS - LIX - LRI - PPS - Copyright 1999-2012     *)
(*   \VV/  **************************************************************)
(*    //   *      This file is distributed under the terms of the       *)
(*         *       GNU Lesser General Public License Version 2.1        *)
(************************************************************************)

open Ppextend
open Constrexpr
open Vernacexpr

type t =
  | AKeyword
  | AUnparsing  of unparsing
  | AConstrExpr of constr_expr
  | AVernac     of vernac_expr

let tag_of_annotation = function
  | AKeyword      -> "keyword"
  | AUnparsing _  -> "unparsing"
  | AConstrExpr _ -> "constr_expr"
  | AVernac _     -> "vernac_expr"

let attributes_of_annotation a =
  []
