%{
(****************************************************************************)
(*                           the diy toolsuite                              *)
(*                                                                          *)
(* Jade Alglave, University College London, UK.                             *)
(* Luc Maranget, INRIA Paris-Rocquencourt, France.                          *)
(*                                                                          *)
(* Copyright 2015-present Institut National de Recherche en Informatique et *)
(* en Automatique and the authors. All rights reserved.                     *)
(*                                                                          *)
(* This software is governed by the CeCILL-B license under French law and   *)
(* abiding by the rules of distribution of free software. You can use,      *)
(* modify and/ or redistribute the software under the terms of the CeCILL-B *)
(* license as circulated by CEA, CNRS and INRIA at the following URL        *)
(* "http://www.cecill.info". We also give a copy in LICENSE.txt.            *)
(****************************************************************************)


open AArch64Base
%}

%token EOF
%token <AArch64Base.reg> ARCH_XREG
%token <string> SYMB_XREG
%token <AArch64Base.reg> ARCH_WREG
%token <string> SYMB_WREG
%token <int> NUM
%token <string> NAME
%token <string> META
%token <string> CODEVAR
%token <int> PROC

%token SEMI COMMA PIPE COLON LBRK RBRK
%token SXTW

/* Instructions */
%token B BEQ BNE CBZ CBNZ EQ NE
%token LDR LDP LDNP STP STNP LDRB LDRH STR STRB STRH LDAR LDAPR LDXR LDAXR STLR STXR STLXR CMP MOV
%token <AArch64Base.op> OP
%token CSEL CSINC CSINV CSNEG
%token DMB DSB ISB
%token SY ST LD
%token OSH OSHST OSHLD
%token ISH ISHST ISHLD
%token NSH NSHST NSHLD
%token CAS CASA CASL CASAL CASB CASAB CASLB CASALB CASH CASAH CASLH CASALH
%token SWP SWPA SWPL SWPAL SWPB SWPAB SWPLB SWPALB SWPH SWPAH SWPLH SWPALH
%token LDADD LDADDA LDADDL LDADDAL LDADDH LDADDAH LDADDLH LDADDALH
%token LDADDB LDADDAB LDADDLB LDADDALB
%token STADD STADDL STADDH STADDLH STADDB STADDLB
%token LDEOR LDEORA LDEORL LDEORAL LDEORH LDEORAH LDEORLH LDEORALH
%token LDEORB LDEORAB LDEORLB LDEORALB
%token STEOR STEORL STEORH STEORLH STEORB STEORLB


%type <int list * (AArch64Base.parsedPseudo) list list> main
%type <AArch64Base.parsedPseudo list> instr_option_seq
%start  main instr_option_seq

%nonassoc SEMI
%%
main:
| semi_opt proc_list iol_list EOF { $2,$3 }

semi_opt:
| { () }
| SEMI { () }

proc_list:
| PROC SEMI
    {[$1]}

| PROC PIPE proc_list  { $1::$3 }

iol_list :
|  instr_option_list SEMI
    {[$1]}
|  instr_option_list SEMI iol_list {$1::$3}

instr_option_list :
  | instr_option
      {[$1]}
  | instr_option PIPE instr_option_list
      {$1::$3}

instr_option_seq :
  | instr_option
      {[$1]}
  | instr_option SEMI instr_option_seq
      {$1::$3}

instr_option :
|            { Nop }
| NAME COLON instr_option { Label ($1,$3) }
| CODEVAR    { Symbolic $1 }
| instr      { Instruction $1}

reg:
| SYMB_XREG { V64,Symbolic_reg $1 }
| ARCH_XREG { V64,$1 }
| SYMB_WREG { V32,Symbolic_reg $1 }
| ARCH_WREG { V32,$1 }

xreg:
| SYMB_XREG { Symbolic_reg $1 }
| ARCH_XREG { $1 }

wreg:
| SYMB_WREG { Symbolic_reg $1 }
| ARCH_WREG { $1 }

k:
| NUM  { MetaConst.Int $1 }
| META { MetaConst.Meta $1 }

kr:
| k { K $1 }
| xreg { RV (V64,$1) }
| wreg COMMA SXTW { RV (V32,$1) }

kr0:
| { K (MetaConst.zero) }
| COMMA kr { $2 }

kwr:
| k { K $1 }
| wreg { RV (V32,$1) }

zeroopt:
| { () }
| COMMA NUM { if $2 <> 0 then raise Parsing.Parse_error }

ldp_instr:
| LDP
  { (fun v r1 r2 r3 kr -> I_LDP (TT,v,r1,r2,r3,kr)) }
| LDNP
  { (fun v r1 r2 r3 kr -> I_LDP (NT,v,r1,r2,r3,kr)) }

stp_instr:
| STP
  { (fun v r1 r2 r3 kr -> I_STP (TT,v,r1,r2,r3,kr)) }
| STNP
  { (fun v r1 r2 r3 kr -> I_STP (NT,v,r1,r2,r3,kr)) }

cond:
| EQ { EQ }
| NE { NE }

instr:
/* Branch */
| B NAME { I_B $2 }
| BEQ NAME { I_BC (EQ,$2) }
| BNE NAME { I_BC (NE,$2) }
| CBZ reg COMMA NAME   { let v,r = $2 in I_CBZ (v,r,$4) }
| CBNZ reg COMMA NAME  { let v,r = $2 in I_CBNZ (v,r,$4) }
/* Memory */
| LDR reg COMMA LBRK xreg kr0 RBRK
  { let v,r = $2 in I_LDR (v,r,$5,$6) }
| ldp_instr wreg COMMA wreg COMMA LBRK xreg kr0 RBRK
  { $1 V32 $2 $4 $7 $8 }
| ldp_instr xreg COMMA xreg COMMA LBRK xreg kr0 RBRK
  { $1 V64 $2 $4 $7 $8 }
| stp_instr wreg COMMA wreg COMMA LBRK xreg kr0 RBRK
  { $1 V32 $2 $4 $7 $8 }
| stp_instr xreg COMMA xreg COMMA LBRK xreg kr0 RBRK
  { $1 V64 $2 $4 $7 $8 }
| LDRB wreg COMMA LBRK xreg kr0 RBRK
  { I_LDRBH (B,$2,$5,$6) }
| LDRH wreg COMMA LBRK xreg kr0 RBRK
  { I_LDRBH (H,$2,$5,$6) }
| LDAR reg COMMA LBRK xreg RBRK
  { let v,r = $2 in I_LDAR (v,AA,r,$5) }
| LDXR reg COMMA LBRK xreg RBRK
  { let v,r = $2 in I_LDAR (v,XX,r,$5) }
| LDAXR reg COMMA LBRK xreg RBRK
  { let v,r = $2 in I_LDAR (v,AX,r,$5) }
| LDAPR reg COMMA LBRK xreg RBRK
  { let v,r = $2 in I_LDAR (v,AQ,r,$5) }
| STR reg COMMA LBRK xreg kr0 RBRK
  { let v,r = $2 in I_STR (v,r,$5,$6) }
| STRB wreg COMMA LBRK xreg kr0 RBRK
  { I_STRBH (B,$2,$5,$6) }
| STRH wreg COMMA LBRK xreg kr0 RBRK
  { I_STRBH (H,$2,$5,$6) }
| STLR reg COMMA LBRK xreg RBRK
  { let v,r = $2 in I_STLR (v,r,$5) }
| STXR wreg COMMA reg COMMA LBRK xreg RBRK
  { let v,r = $4 in I_STXR (v,YY,$2,r,$7) }
| STLXR wreg COMMA reg COMMA LBRK xreg RBRK
  { let v,r = $4 in I_STXR (v,LY,$2,r,$7) }
/* Compare and swap */
| CAS wreg COMMA wreg COMMA  LBRK xreg zeroopt RBRK
  { I_CAS (V32,RMW_P,$2,$4,$7) }
| CAS xreg COMMA xreg COMMA  LBRK xreg zeroopt RBRK
  { I_CAS (V64,RMW_P,$2,$4,$7) }
| CASA wreg COMMA wreg COMMA  LBRK xreg zeroopt RBRK
  { I_CAS (V32,RMW_A,$2,$4,$7) }
| CASA xreg COMMA xreg COMMA  LBRK xreg zeroopt RBRK
  { I_CAS (V64,RMW_A,$2,$4,$7) }
| CASL wreg COMMA wreg COMMA  LBRK xreg zeroopt RBRK
  { I_CAS (V32,RMW_L,$2,$4,$7) }
| CASL xreg COMMA xreg COMMA  LBRK xreg zeroopt RBRK
  { I_CAS (V64,RMW_L,$2,$4,$7) }
| CASAL wreg COMMA wreg COMMA  LBRK xreg zeroopt RBRK
  { I_CAS (V32,RMW_AL,$2,$4,$7) }
| CASAL xreg COMMA xreg COMMA  LBRK xreg zeroopt RBRK
  { I_CAS (V64,RMW_AL,$2,$4,$7) }
| CASB wreg COMMA wreg COMMA  LBRK xreg zeroopt RBRK
  { I_CASBH (B,RMW_P,$2,$4,$7) }
| CASAB wreg COMMA wreg COMMA  LBRK xreg zeroopt RBRK
  { I_CASBH (B,RMW_A,$2,$4,$7) }
| CASLB wreg COMMA wreg COMMA  LBRK xreg zeroopt RBRK
  { I_CASBH (B,RMW_L,$2,$4,$7) }
| CASALB wreg COMMA wreg COMMA  LBRK xreg zeroopt RBRK
  { I_CASBH (B,RMW_AL,$2,$4,$7) }
| CASH wreg COMMA wreg COMMA  LBRK xreg zeroopt RBRK
  { I_CASBH (H,RMW_P,$2,$4,$7) }
| CASAH wreg COMMA wreg COMMA  LBRK xreg zeroopt RBRK
  { I_CASBH (H,RMW_A,$2,$4,$7) }
| CASLH wreg COMMA wreg COMMA  LBRK xreg zeroopt RBRK
  { I_CASBH (H,RMW_L,$2,$4,$7) }
| CASALH wreg COMMA wreg COMMA  LBRK xreg zeroopt RBRK
  { I_CASBH (H,RMW_AL,$2,$4,$7) }
/* Swap */
| SWP wreg COMMA wreg COMMA  LBRK xreg zeroopt RBRK
  { I_SWP (V32,RMW_P,$2,$4,$7) }
| SWP xreg COMMA xreg COMMA  LBRK xreg zeroopt RBRK
  { I_SWP (V64,RMW_P,$2,$4,$7) }
| SWPA wreg COMMA wreg COMMA  LBRK xreg zeroopt RBRK
  { I_SWP (V32,RMW_A,$2,$4,$7) }
| SWPA xreg COMMA xreg COMMA  LBRK xreg zeroopt RBRK
  { I_SWP (V64,RMW_A,$2,$4,$7) }
| SWPL wreg COMMA wreg COMMA  LBRK xreg zeroopt RBRK
  { I_SWP (V32,RMW_L,$2,$4,$7) }
| SWPL xreg COMMA xreg COMMA  LBRK xreg zeroopt RBRK
  { I_SWP (V64,RMW_L,$2,$4,$7) }
| SWPAL wreg COMMA wreg COMMA  LBRK xreg zeroopt RBRK
  { I_SWP (V32,RMW_AL,$2,$4,$7) }
| SWPAL xreg COMMA xreg COMMA  LBRK xreg zeroopt RBRK
  { I_SWP (V64,RMW_AL,$2,$4,$7) }
| SWPB wreg COMMA wreg COMMA  LBRK xreg zeroopt RBRK
  { I_SWPBH (B,RMW_P,$2,$4,$7) }
| SWPAB wreg COMMA wreg COMMA  LBRK xreg zeroopt RBRK
  { I_SWPBH (B,RMW_A,$2,$4,$7) }
| SWPLB wreg COMMA wreg COMMA  LBRK xreg zeroopt RBRK
  { I_SWPBH (B,RMW_L,$2,$4,$7) }
| SWPALB wreg COMMA wreg COMMA  LBRK xreg zeroopt RBRK
  { I_SWPBH (B,RMW_AL,$2,$4,$7) }
| SWPH wreg COMMA wreg COMMA  LBRK xreg zeroopt RBRK
  { I_SWPBH (H,RMW_P,$2,$4,$7) }
| SWPAH wreg COMMA wreg COMMA  LBRK xreg zeroopt RBRK
  { I_SWPBH (H,RMW_A,$2,$4,$7) }
| SWPLH wreg COMMA wreg COMMA  LBRK xreg zeroopt RBRK
  { I_SWPBH (H,RMW_L,$2,$4,$7) }
| SWPALH wreg COMMA wreg COMMA  LBRK xreg zeroopt RBRK
  { I_SWPBH (H,RMW_AL,$2,$4,$7) }

/* Fetch and ADD */
| LDADD wreg COMMA wreg COMMA  LBRK xreg zeroopt RBRK
   { I_LDOP (A_ADD,V32,RMW_P,$2,$4,$7) }
| LDADD xreg COMMA xreg COMMA  LBRK xreg zeroopt RBRK
   { I_LDOP (A_ADD,V64,RMW_P,$2,$4,$7) }
| LDADDA wreg COMMA wreg COMMA  LBRK xreg zeroopt RBRK
   { I_LDOP (A_ADD,V32,RMW_A,$2,$4,$7) }
| LDADDA xreg COMMA xreg COMMA  LBRK xreg zeroopt RBRK
   { I_LDOP (A_ADD,V64,RMW_A,$2,$4,$7) }
| LDADDL wreg COMMA wreg COMMA  LBRK xreg zeroopt RBRK
   { I_LDOP (A_ADD,V32,RMW_L,$2,$4,$7) }
| LDADDL xreg COMMA xreg COMMA  LBRK xreg zeroopt RBRK
   { I_LDOP (A_ADD,V64,RMW_L,$2,$4,$7) }
| LDADDAL wreg COMMA wreg COMMA  LBRK xreg zeroopt RBRK
   { I_LDOP (A_ADD,V32,RMW_AL,$2,$4,$7) }
| LDADDAL xreg COMMA xreg COMMA  LBRK xreg zeroopt RBRK
   { I_LDOP (A_ADD,V64,RMW_AL,$2,$4,$7) }
| LDADDH wreg COMMA wreg COMMA  LBRK xreg zeroopt RBRK
   { I_LDOPBH (A_ADD,H,RMW_P,$2,$4,$7) }
| LDADDAH wreg COMMA wreg COMMA  LBRK xreg zeroopt RBRK
   { I_LDOPBH (A_ADD,H,RMW_A,$2,$4,$7) }
| LDADDLH wreg COMMA wreg COMMA  LBRK xreg zeroopt RBRK
   { I_LDOPBH (A_ADD,H,RMW_L,$2,$4,$7) }
| LDADDALH wreg COMMA wreg COMMA  LBRK xreg zeroopt RBRK
   { I_LDOPBH (A_ADD,H,RMW_AL,$2,$4,$7) }
| LDADDB wreg COMMA wreg COMMA  LBRK xreg zeroopt RBRK
   { I_LDOPBH (A_ADD,B,RMW_P,$2,$4,$7) }
| LDADDAB wreg COMMA wreg COMMA  LBRK xreg zeroopt RBRK
   { I_LDOPBH (A_ADD,B,RMW_A,$2,$4,$7) }
| LDADDLB wreg COMMA wreg COMMA  LBRK xreg zeroopt RBRK
   { I_LDOPBH (A_ADD,B,RMW_L,$2,$4,$7) }
| LDADDALB wreg COMMA wreg COMMA  LBRK xreg zeroopt RBRK
   { I_LDOPBH (A_ADD,B,RMW_AL,$2,$4,$7) }
| STADD wreg COMMA LBRK xreg zeroopt RBRK
   { I_STOP (A_ADD,V32,W_P,$2,$5) }
| STADD xreg COMMA LBRK xreg zeroopt RBRK
   { I_STOP (A_ADD,V64,W_P,$2,$5) }
| STADDL wreg COMMA LBRK xreg zeroopt RBRK
   { I_STOP (A_ADD,V32,W_L,$2,$5) }
| STADDL xreg COMMA LBRK xreg zeroopt RBRK
   { I_STOP (A_ADD,V64,W_L,$2,$5) }
| STADDH wreg COMMA LBRK xreg zeroopt RBRK
   { I_STOPBH (A_ADD,H,W_P,$2,$5) }
| STADDLH wreg COMMA LBRK xreg zeroopt RBRK
   { I_STOPBH (A_ADD,H,W_L,$2,$5) }
| STADDB wreg COMMA LBRK xreg zeroopt RBRK
   { I_STOPBH (A_ADD,B,W_P,$2,$5) }
| STADDLB wreg COMMA LBRK xreg zeroopt RBRK
   { I_STOPBH (A_ADD,B,W_L,$2,$5) }
/* Fetch and Xor */
| LDEOR wreg COMMA wreg COMMA  LBRK xreg zeroopt RBRK
   { I_LDOP (A_EOR,V32,RMW_P,$2,$4,$7) }
| LDEOR xreg COMMA xreg COMMA  LBRK xreg zeroopt RBRK
   { I_LDOP (A_EOR,V64,RMW_P,$2,$4,$7) }
| LDEORA wreg COMMA wreg COMMA  LBRK xreg zeroopt RBRK
   { I_LDOP (A_EOR,V32,RMW_A,$2,$4,$7) }
| LDEORA xreg COMMA xreg COMMA  LBRK xreg zeroopt RBRK
   { I_LDOP (A_EOR,V64,RMW_A,$2,$4,$7) }
| LDEORL wreg COMMA wreg COMMA  LBRK xreg zeroopt RBRK
   { I_LDOP (A_EOR,V32,RMW_L,$2,$4,$7) }
| LDEORL xreg COMMA xreg COMMA  LBRK xreg zeroopt RBRK
   { I_LDOP (A_EOR,V64,RMW_L,$2,$4,$7) }
| LDEORAL wreg COMMA wreg COMMA  LBRK xreg zeroopt RBRK
   { I_LDOP (A_EOR,V32,RMW_AL,$2,$4,$7) }
| LDEORAL xreg COMMA xreg COMMA  LBRK xreg zeroopt RBRK
   { I_LDOP (A_EOR,V64,RMW_AL,$2,$4,$7) }
| LDEORH wreg COMMA wreg COMMA  LBRK xreg zeroopt RBRK
   { I_LDOPBH (A_EOR,H,RMW_P,$2,$4,$7) }
| LDEORAH wreg COMMA wreg COMMA  LBRK xreg zeroopt RBRK
   { I_LDOPBH (A_EOR,H,RMW_A,$2,$4,$7) }
| LDEORLH wreg COMMA wreg COMMA  LBRK xreg zeroopt RBRK
   { I_LDOPBH (A_EOR,H,RMW_L,$2,$4,$7) }
| LDEORALH wreg COMMA wreg COMMA  LBRK xreg zeroopt RBRK
   { I_LDOPBH (A_EOR,H,RMW_AL,$2,$4,$7) }
| LDEORB wreg COMMA wreg COMMA  LBRK xreg zeroopt RBRK
   { I_LDOPBH (A_EOR,B,RMW_P,$2,$4,$7) }
| LDEORAB wreg COMMA wreg COMMA  LBRK xreg zeroopt RBRK
   { I_LDOPBH (A_EOR,B,RMW_A,$2,$4,$7) }
| LDEORLB wreg COMMA wreg COMMA  LBRK xreg zeroopt RBRK
   { I_LDOPBH (A_EOR,B,RMW_L,$2,$4,$7) }
| LDEORALB wreg COMMA wreg COMMA  LBRK xreg zeroopt RBRK
   { I_LDOPBH (A_EOR,B,RMW_AL,$2,$4,$7) }
| STEOR wreg COMMA LBRK xreg zeroopt RBRK
   { I_STOP (A_EOR,V32,W_P,$2,$5) }
| STEOR xreg COMMA LBRK xreg zeroopt RBRK
   { I_STOP (A_EOR,V64,W_P,$2,$5) }
| STEORL wreg COMMA LBRK xreg zeroopt RBRK
   { I_STOP (A_EOR,V32,W_L,$2,$5) }
| STEORL xreg COMMA LBRK xreg zeroopt RBRK
   { I_STOP (A_EOR,V64,W_L,$2,$5) }
| STEORH wreg COMMA LBRK xreg zeroopt RBRK
   { I_STOPBH (A_EOR,H,W_P,$2,$5) }
| STEORLH wreg COMMA LBRK xreg zeroopt RBRK
   { I_STOPBH (A_EOR,H,W_L,$2,$5) }
| STEORB wreg COMMA LBRK xreg zeroopt RBRK
   { I_STOPBH (A_EOR,B,W_P,$2,$5) }
| STEORLB wreg COMMA LBRK xreg zeroopt RBRK
   { I_STOPBH (A_EOR,B,W_L,$2,$5) }
/* Operations */
| MOV xreg COMMA kr
  { I_MOV (V64,$2,$4) }
| MOV wreg COMMA kwr
  { I_MOV (V32,$2,$4) }
| SXTW xreg COMMA wreg
  { I_SXTW ($2,$4) }
| OP xreg COMMA xreg COMMA kr
  { I_OP3 (V64,$1,$2,$4,$6) }
| OP wreg COMMA wreg COMMA kwr
    { I_OP3 (V32,$1,$2,$4,$6) }
| CMP wreg COMMA kwr
  { I_OP3 (V32,SUBS,ZR,$2,$4) }
| CMP xreg COMMA kr
  { I_OP3 (V64,SUBS,ZR,$2,$4) }
/* Misc */
| CSEL xreg COMMA  xreg COMMA  xreg COMMA cond
  { I_CSEL (V64,$2,$4,$6,$8,Cpy) }
| CSEL wreg COMMA  wreg COMMA  wreg COMMA cond
  { I_CSEL (V32,$2,$4,$6,$8,Cpy) }
| CSINC xreg COMMA  xreg COMMA  xreg COMMA cond
  { I_CSEL (V64,$2,$4,$6,$8,Inc) }
| CSINC wreg COMMA  wreg COMMA  wreg COMMA cond
  { I_CSEL (V32,$2,$4,$6,$8,Inc) }
| CSINV xreg COMMA  xreg COMMA  xreg COMMA cond
  { I_CSEL (V64,$2,$4,$6,$8,Inv) }
| CSINV wreg COMMA  wreg COMMA  wreg COMMA cond
  { I_CSEL (V32,$2,$4,$6,$8,Inv) }
| CSNEG xreg COMMA  xreg COMMA  xreg COMMA cond
  { I_CSEL (V64,$2,$4,$6,$8,Neg) }
| CSNEG wreg COMMA  wreg COMMA  wreg COMMA cond
  { I_CSEL (V32,$2,$4,$6,$8,Neg) }

/* Fences */
| DMB fenceopt
  { let d,t = $2 in I_FENCE (DMB (d,t)) }
| DSB fenceopt
  { let d,t = $2 in I_FENCE (DSB (d,t)) }
| ISB
  { I_FENCE ISB }

fenceopt:
| SY
  { SY,FULL }
| ST
  { SY,ST }
| LD
  { SY,LD }
| OSH
  { OSH,FULL }
| OSHST
  { OSH,ST }
| OSHLD
  { OSH,LD }
| ISH
  { ISH,FULL }
| ISHST
  { ISH,ST }
| ISHLD
  { ISH,LD }
| NSH
  { NSH,FULL }
| NSHST
  { NSH,ST }
| NSHLD
  { NSH,LD}
