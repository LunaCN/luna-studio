{-# OPTIONS_GHC -fno-warn-orphans #-}

{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeSynonymInstances #-}
{-# LANGUAGE LambdaCase #-}


module Luna.Typechecker.Inference (
    tcpass
  ) where


import qualified  Luna.Data.StructInfo                    as SI
import            Luna.Data.StructInfo                    (StructInfo)

import            Luna.Pass                               (Pass(..))

import            Luna.Syntax.Decl                        (LDecl)
import qualified  Luna.Syntax.Enum                        as Enum
import            Luna.Syntax.Enum                        (Enumerated, ID)
import qualified  Luna.Syntax.Expr                        as Expr
import            Luna.Syntax.Expr                        (LExpr)
import            Luna.Syntax.Label                       (Label(Label))
import            Luna.Syntax.Module                      (LModule)
import qualified  Luna.Syntax.Name.Pattern                as NamePat
import qualified  Luna.Syntax.Pat                         as Pat
import qualified  Luna.Syntax.Traversals                  as AST

import            Control.Applicative
import            Control.Lens                            hiding (without)
import            Control.Monad.State

import            Data.Monoid
import            Data.Text.Lazy                          (unpack)

import            Luna.Typechecker.Debug.HumanName        (HumanName(humanName))
import            Luna.Typechecker.Data
import            Luna.Typechecker.StageTypecheckerState  (
                      StageTypecheckerState(..), debugLog, typo, nextTVar, subst, constr, sa,
                      StageTypechecker(..),
                      StageTypecheckerPass, StageTypecheckerCtx,
                      StageTypecheckerTraversal, StageTypecheckerDefaultTraversal,
                      report_error
                  )
import            Luna.Typechecker.Tools                  (without)
import            Luna.Typechecker.TypesAndConstraints
import            Luna.Typechecker.Solver                 (cs)





tcpass :: (StageTypecheckerDefaultTraversal m a) => Pass StageTypecheckerState (a -> StructInfo -> StageTypecheckerPass m StageTypecheckerState)
tcpass = Pass { _name  = "Typechecker"
              , _desc  = "Infers the types and typechecks the program as a form of correctness-proving."
              , _state = StageTypecheckerState  { _debugLog = []
                                                , _typo     = init_typo
                                                , _nextTVar = 0
                                                , _subst    = null_subst
                                                , _constr   = true_cons
                                                , _sa       = mempty
                                                }
              , _func  = tcUnit
              }

tcUnit :: (StageTypecheckerDefaultTraversal m a) => a -> StructInfo -> StageTypecheckerPass m StageTypecheckerState
tcUnit ast structAnalysis = do
    sa .= structAnalysis
    debugPush "First!"
    _ <- defaultTraverseM ast
    debugLog %= reverse
    get


instance (StageTypecheckerCtx lab m a) => AST.Traversal StageTypechecker (StageTypecheckerPass m) (LDecl lab a)    (LDecl lab a)   where traverseM _ = tcDecl
instance (StageTypecheckerCtx lab m a) => AST.Traversal StageTypechecker (StageTypecheckerPass m) (LExpr lab a)    (LExpr lab a)   where traverseM _ = tcExpr

traverseM :: (StageTypecheckerTraversal m a) => a -> StageTypecheckerPass m a
traverseM = AST.traverseM StageTypechecker

defaultTraverseM :: (StageTypecheckerDefaultTraversal m a) => a -> StageTypecheckerPass m a
defaultTraverseM = AST.defaultTraverseM StageTypechecker




---- top-level program

--infer :: Term -> E (TVar, Subst, Constraint, Type)
--infer e = unTP (tp (init_typo, e)) (init_tvar, null_subst, true_cons)
----


withTypo ::  (StageTypecheckerCtx lab m a) => Typo -> x lab a -> (x lab a -> StageTypecheckerPass m (x lab a)) -> StageTypecheckerPass m (x lab a)
withTypo typeEnv astElem action = push *> action astElem <* pop
  where
    push = typo %= (typeEnv:)
    pop  = typo %= tail       -- TODO [kgdk] 22 sty 2015: probable cause of problems in the future


tcDecl :: (StageTypecheckerCtx lab m a) => LDecl lab a -> StageTypecheckerPass m (LDecl lab a)
tcDecl = defaultTraverseM
  --  case decl of
  --      fun@Decl.Func { Decl._sig  = sig@NamePat.NamePat{ NamePat._base = (NamePat.Segment name args) }
  --                    , Decl._body = body
  --                    } ->
  --        do  
  --          --tp (env, Abs x e) = do a <- newtvar
  --          --                       b <- tp (insert env (x, Mono (TV a)), e)
  --          --                       normalize ((TV a) `Fun` b)
  --          name_ids <- getTargetIDString lab
  --          args_ids <- unwords <$> mapM mapArg args
  --          debugPush ("Function    " ++ unpack name ++ name_ids ++ " " ++ args_ids ++ " START")
  --          x <- defaultTraverseM ldecl

  --          debugPush ("Function    " ++ unpack name ++ name_ids ++ " " ++ args_ids ++ " END") 
  --          return x
  --      _ ->
  --          defaultTraverseM ldecl
  --where 
  --  mapArg :: (Enumerated lab, Monad m) => NamePat.Arg (Pat.LPat lab) a -> StageTypecheckerPass m String
  --  mapArg (NamePat.Arg (Label laba arg) _) =
  --    do
  --      arg_id <- getTargetIDString laba
  --      return $ unpack (humanName arg) ++ arg_id


tcExpr :: (StageTypecheckerCtx lab m a) => LExpr lab a -> StageTypecheckerPass m (LExpr lab a)
tcExpr lexpr@(Label lab expr) = do
    case expr of 
        --tp :: (Monad m) =>  (Typo, Term) ->  StageTypecheckerPass m Type
        --tp (env, Id x) =  do a <- inst env x
        --                     normalize a
        Expr.Var { Expr._ident = (Expr.Variable vname _) } ->
          do
            let hn = unpack . humanName $ vname
            hn_id <- getTargetIDString lab
            debugPush ("Var         " ++ hn ++ hn_id)
            targetLabel <- getTargetID lab

            currentType <- currentType

            env <- getEnv
            vType <- inst env targetLabel
            result <- normalize vType
            debugPush ("         :: " ++ show result)
            currentType .= result
        Expr.Assignment { Expr._dst = (Label labt dst), Expr._src = (Label labs src) } ->

            case (dst, src) of
                (Pat.Var { Pat._vname = dst_vname }, Expr.Var { Expr._ident = (Expr.Variable src_vname _) }) ->
                  do  
                    --tp (env, Let x e e') = do a <- tp (env, e)
                    --                          b <- gen env a
                    --                          tp ((insert env (x, b)), e')
                    t_id <- getTargetIDString labt
                    s_id <- getTargetIDString labs
                    debugPush ("Assignment  " ++ unpack (humanName dst_vname) ++ t_id ++ " ⬸ " ++ unpack (humanName src_vname) ++ s_id) 
                _ -> debugPush "Some assignment..."
        Expr.App (NamePat.NamePat { NamePat._base = (NamePat.Segment (Label labb (Expr.Var { Expr._ident = (Expr.Variable basename _)})) args)}) ->
          do
            --tp (env, App e e') = do a <- newtvar
            --                        t <- tp (env, e)
            --                        t' <- tp (env, e')
            --                        add_constraint (C [t `Subsume` (t' `Fun` TV a)])
            --                        normalize (TV a)
            base_id <- getTargetIDString labb
            args_id <- unwords <$> mapM mapArg args
            debugPush ("Application " ++ (unpack . humanName $ basename) ++ base_id ++ " ( " ++ args_id ++ " )")
            
            j
        _ ->
            return ()
    defaultTraverseM lexpr
  where 
    -- TODO wyciaga tylko nazwy zmiennych jako argumenty, przerobic na
    -- akceptujace wyrazenia
    mapArg :: (StageTypecheckerCtx lab m a) => Expr.AppArg (LExpr lab a) -> StageTypecheckerPass m String
    mapArg (Expr.AppArg _ (Label laba (Expr.Var { Expr._ident = (Expr.Variable vname _) } ))) = do
        arg_id <- getTargetIDString laba
        return $ (unpack . humanName $ vname) ++ arg_id
    mapArg _ = fail "Luna.Typechecker.Inference:tcExpr:mapArg: usage unexpected"



debugPush :: (Monad m) => String -> StageTypecheckerPass m ()
debugPush s = debugLog %= (s:)


getTargetIDString :: (StageTypecheckerCtx lab m String) => lab -> StageTypecheckerPass m String
getTargetIDString lab = do
    labtID <- getTargetID lab
    return $ "|" ++ show labID ++ "⊳" ++ show labtID ++ "⊲"
  where
    labID = Enum.id lab


getTargetID :: (StageTypecheckerCtx lab m String) => lab -> StageTypecheckerPass m ID
getTargetID lab =
    sa . SI.alias . ix labID . SI.target & preuse >>= \case
        Nothing     -> return labID
        Just labtID -> return labtID
  where
    labID = Enum.id lab

getEnv :: (Monad m) => StageTypecheckerPass m Typo
getEnv =
    typo & use >>= \case
        []    -> return []
        (x:_) -> return x



-- TODO [kgdk] 22 sty 2015: Constraint should be a monoid
add_cons :: Constraint -> Constraint -> Constraint
add_cons (C p1) (C p2)               = C (p1 ++ p2)
add_cons (C p1) (Proj tvr p2)        = Proj tvr (p1 ++ p2)
add_cons (Proj tvr p1) (C p2)        = Proj tvr (p1 ++ p2)
add_cons (Proj tv1 p1) (Proj tv2 p2) = Proj (tv1 ++ tv2) (p1 ++ p2)


tv_typo :: Typo -> [TVar]
tv_typo = foldl f []
  where
    f z (v,ts) = z ++ tv ts


add_constraint :: (Monad m) => Constraint -> StageTypecheckerPass m ()
add_constraint c1 =
    constr %= (`add_cons` c1)


newtvar :: (Monad m) => StageTypecheckerPass m TVar
newtvar = use nextTVar <* (nextTVar += 1)


insert :: Typo -> (Var, TypeScheme) -> Typo
insert a (x,t) = (x,t):a


rename :: (Monad m) => StageTypecheckerPass m Subst -> TVar ->  StageTypecheckerPass m Subst
rename s x = do
    newtv <- newtvar
    s' <- s
    return ((x, TV newtv):s')


inst :: (Monad m) => Var -> StageTypecheckerPass m Type
inst env x = do
    case lookup x env -- mylookup env x of
        Just ts -> case ts of
            Mono t        ->
                return t
            Poly tvl c t  ->
              do
                s' <- foldl rename (return null_subst) tvl
                c' <- apply s' c
                t' <- apply s' t
                add_constraint c'
                return t'
        Nothing ->
          do
            ntv <- newtvar
            report_error "undeclared variable" (TV ntv)
  where
    mylookup :: Typo -> Var -> Maybe TypeScheme
    mylookup [] y = Nothing
    mylookup ((xx,tt):xs) y =
          if xx == y then return tt
                    else mylookup xs y


gen :: (Monad m) =>  Typo -> Type -> StageTypecheckerPass m TypeScheme
gen env t = do
    c      <- use constr
    constr .= projection c (fv t c env)
    return  $ Poly (fv t c env) c t
  where
    fv t1 c1 env1 = without (tv t1 ++ tv c1) (tv_typo env1)


normalize :: (Monad m) => Type ->  StageTypecheckerPass m Type
normalize a = do s <- use subst
                 c <- use constr
                 (s',c') <- cs (s,c)
                 t <- apply s' a
                 return_result s' c' t


return_result :: (Monad m) =>  Subst -> Constraint -> Type ->  StageTypecheckerPass m Type
return_result s c t = do
    subst  .= s
    constr .= c
    return t


projection :: Constraint -> [TVar] -> Constraint
projection _ _ = true_cons

