{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DisambiguateRecordFields #-}

module HoverPlugin (descriptor) where

import Development.IDE
import Ide.Types
import Ide.Logger (Recorder, WithPriority,Pretty(..))
import Language.LSP.Protocol.Types
import Language.LSP.Protocol.Message (SMethod(..))
import Control.Monad.IO.Class (liftIO)
import qualified Data.Text as T
import Development.IDE.GHC.Compat (RealSrcSpan)
import Development.IDE.GHC.Util (printOutputable)
import GHC.Iface.Ext.Types    -- This gives us HieAST, nodeSpan, and nodeChildren
import GHC.Types.SrcLoc       -- This gives us RealSrcSpan and the line/col getters
import qualified Data.Map as M -- To unpack the dictionary of trees
import Data.Typeable (cast)
import Data.Maybe (mapMaybe)
import GHC.Core.Type (Type)  
import Data.List (nub)

-- | We define a dummy Log type
data Log = LogNone

instance Pretty Log where
    pretty LogNone = "HoverPlugin Activated"
pluginId :: PluginId
pluginId = "aditya-hover-plugin"

-- | The Descriptor
descriptor :: Recorder (WithPriority Log) -> PluginId -> PluginDescriptor IdeState
descriptor _ plId = (defaultPluginDescriptor plId "Provides custom AST hover info")
    { pluginHandlers = mkPluginHandler SMethod_TextDocumentHover hoverHandler }

-- | The Handler 
hoverHandler state _pId params = do
    
    -- let myTest = "**plugin is alive**"
    
    -- let HoverParams{_position = pos} = params
    -- let Position{_line = currLine, _character = currCol} = pos
    -- let myText = " **Position Tracker:** You are hovering at Line "
    --              <>T.pack (show currLine)
    --              <> "column"
    --              <> T.pack (show currCol)
    let HoverParams{_textDocument = TextDocumentIdentifier{_uri = uri}, _position = pos} = params
    let Position{_line = currLine, _character = currCol} = pos
   

    case uriToFilePath' uri of
        Nothing -> pure (InR Null)
        Just filePath -> do

            let nfp = toNormalizedFilePath' filePath
            maybeAst <- liftIO $ runAction "HoverPlugin" state $ use GetHieAst nfp
            case maybeAst of
                Nothing -> pure (InR Null)
                Just HAR{hieAst = asts} -> do
                    let ghcLine = fromIntegral currLine +1
                        ghcCol = fromIntegral currCol + 1
                        allTrees = M.elems (getAsts asts)

                        maybeNode = case allTrees of
                            (tree:_) -> findDeepestNode ghcLine ghcCol tree
                            [] -> Nothing
                                        

                    case maybeNode of
                        Nothing -> pure (InR Null)
                        Just targetNode -> do
                            -- let bounds = nodeSpan targetNode

                            -- let myText = " **found the AST Node**\n\n" 
                            --              <> "This exact node starts at Line " <> T.pack (show (srcSpanStartLine bounds))
                            --              <> ", Column " <> T.pack (show (srcSpanStartCol bounds)) <> "\n"
                            --              <> "And ends at Line " <> T.pack (show (srcSpanEndLine bounds))
                            --              <> ", Column " <> T.pack (show (srcSpanEndCol bounds))
                         
                            let infos = M.elems (getSourcedNodeInfo (sourcedNodeInfo targetNode))
                                -- extracting the node info from the HieAst node into infos
                                idents = concatMap (M.keys . nodeIdentifiers) infos
                                -- mapping the identifiers from the infos to idents
                                printIdent (Left modName) = printOutputable modName
                                printIdent (Right name)   = printOutputable name
                                rawIdentTexts = map printIdent idents
                                cleanIdents = filter (\t-> not ("$" `T.isPrefixOf` t)) (nub rawIdentTexts)
                                formatList items = T.intercalate "\n" $ map (\i -> "* `" <> i <> "`") items
                                
                                identSection = if null cleanIdents 
                                               then "* *(No public identifiers)*" 
                                               else formatList cleanIdents

                                rawTypes = concatMap nodeType infos
                                -- mapping the typeChecked value from the infos to rawTypes
                                actualTypes = mapMaybe cast rawTypes :: [Type]
                                typeText = nub (map printOutputable actualTypes)
                                
                                typeSection = if null typeText
                                              then "* *(No type data)*" 
                                              else formatList typeText

                                myText = "🎯 *Adpad's Plugin*\n\n" 
                                         <> "**Identifierss:*" 
                                         <> identSection <> "\n\n"
                                         <> "**Types:**\n" <> typeSection
                        
                                markup = MarkupContent MarkupKind_Markdown myText
                                hoverInfo = Hover (InL markup) Nothing
                            pure (InL hoverInfo)
                            
-- | to check if the selected node contains teh point
containsPoint :: RealSrcSpan -> Int ->Int -> Bool
containsPoint spn line col =
    let startLine = srcSpanStartLine spn
        endLine   = srcSpanEndLine spn
        startCol  = srcSpanStartCol spn
        endCol    = srcSpanEndCol spn
    in (line > startLine || (line == startLine && col >= startCol)) &&
       (line < endLine   || (line == endLine   && col <= endCol))
-- | to find the deepest node as much as possible to triangulate the position of the expression
findDeepestNode :: Int -> Int -> HieAST a -> Maybe (HieAST a)
findDeepestNode line col node=
    if containsPoint (nodeSpan node) line col
    then 
        let matchingChildren = filter (\child -> containsPoint (nodeSpan child) line col) (nodeChildren node)
        in case matchingChildren of
            [] -> Just node
            (child:_) -> findDeepestNode line col child
    else 
        Nothing

