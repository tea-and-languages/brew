Code Export
===========

    <<global:code export definitions>>=
    void ExportScrapFileGroup(
        MgContext*        context,
        MgScrapFileGroup* scrapFileGroup,
        MgWriter*         writer );

    void ExportScrapElements(
        MgContext*  context,
        MgScrap*    scrap,
        MgElement*  firstElement,
        MgWriter*   writer,
        int         indent );

    void WriteInt(
        MgWriter*     writer,
        int         value)
    {
        enum
        {
            kBufferSize = 16,
        };
        char buffer[kBufferSize];
        char* cursor = &buffer[kBufferSize];
        *(--cursor) = 0;

        int remaining = value;
        do
        {
            int digit = remaining % 10;
            remaining = remaining / 10;

            *(--cursor) = '0' + digit;
        } while( remaining != 0 );

        MgWriteCString(writer, cursor);
    }

    static void Indent(
        MgWriter*   writer,
        int         indent )
    {
        for( int ii = 1; ii < indent; ++ii )
            MgWriteCString(writer, " ");    
    }

    void EmitLineDirectiveAndIndent(
        MgWriter*     writer,
        MgInputFile*  inputFile,
        MgSourceLoc   loc)
    {
        MgWriteCString(writer, "\n#line ");
        WriteInt(writer, loc.line);
        MgWriteCString(writer, " \"");

        char const* cc = inputFile->path;
        for(;;)
        {
            int c = *cc++;
            if( !c ) break;

            switch(c)
            {
            case '\\':
                MgPutChar(writer, '/');
                break;

            // TODO: other characters that might need escaping?

            default:
                MgPutChar(writer, c);
                break;
            }
        }
        MgWriteCString(writer, "\"\n");

        Indent( writer, loc.col );
    }

    void ExportScrapElement(
        MgContext*  context,
        MgScrap*    scrap,
        MgElement*  element,
        MgWriter*   writer,
        int         indent )
    {
        switch( element->kind )
        {
        case kMgElementKind_CodeBlock:
        case kMgElementKind_Text:
            MgWriteString(writer, element->text);
            ExportScrapElements(context, scrap, element->firstChild, writer, indent);
            break;

        case kMgElementKind_NewLine:
            MgWriteString(writer, element->text);
            Indent( writer, indent );
            break;

        case kMgElementKind_LessThanEntity:
            MgWriteCString(writer, "<");
            break;
        case kMgElementKind_GreaterThanEntity:
            MgWriteCString(writer, ">");
            break;
        case kMgElementKind_AmpersandEntity:
            MgWriteCString(writer, "&");
            break;

        case kMgElementKind_ScrapRef:
            {
                MgScrapFileGroup* scrapGroup = MgFindAttribute(element, "$scrap-group")->scrapFileGroup;
                ExportScrapFileGroup(context, scrapGroup, writer);
                if(scrapGroup->nameGroup->kind != kScrapKind_RawMacro)
                {
                    MgSourceLoc resumeLoc = MgFindAttribute(element, "$resume-at")->sourceLoc;
                    EmitLineDirectiveAndIndent(writer, scrap->fileGroup->inputFile, resumeLoc);
                }
            }
            break;

        default:
            assert(MG_FALSE);
            break;
        }
    }

    void ExportScrapElements(
        MgContext*  context,
        MgScrap*    scrap,
        MgElement*  firstElement,
        MgWriter*   writer,
        int         indent )
    {
        for( MgElement* element = firstElement; element; element = element->next )
            ExportScrapElement( context, scrap, element, writer, indent );
    }

    void ExportScrapText(
        MgContext*    context,
        MgScrap*      scrap,
        MgWriter*     writer )
    {
        if(scrap->fileGroup->nameGroup->kind != kScrapKind_RawMacro)
        {
            EmitLineDirectiveAndIndent(writer, scrap->fileGroup->inputFile, scrap->sourceLoc);
        }
        ExportScrapElements(
            context,
            scrap,
            scrap->body,
            writer,
            scrap->sourceLoc.col );
    }


    void ExportScrapFileGroupImpl(
        MgContext*        context,
        MgScrapFileGroup* fileGroup,
        MgWriter*         writer )
    {
        MgScrap* scrap = fileGroup->firstScrap;
        while( scrap )
        {
            ExportScrapText( context, scrap, writer );
            scrap = scrap->next;
        }
    }

    

    void ExportScrapNameGroupImpl(
        MgContext*        context,
        MgScrapNameGroup* nameGroup,
        MgWriter*         writer )
    {
        MgScrapFileGroup* fileGroup = nameGroup->firstFileGroup;
        while( fileGroup )
        {
            ExportScrapFileGroupImpl( context, fileGroup, writer );
            fileGroup = fileGroup->next;
        }
    }

    void resetExportedFlags(
        MgScrapNameGroup* nameGroup);

    void resetExportedFlagsImplRec(
        MgScrap*      scrap,
        MgElement*    element);

    void resetExportedFlagsImpl(
        MgScrap*    scrap,
        MgElement*  element )
    {
        switch( element->kind )
        {
        case kMgElementKind_CodeBlock:
        case kMgElementKind_Text:
            resetExportedFlagsImplRec(scrap, element->firstChild);
            break;

        case kMgElementKind_ScrapRef:
            {
                MgScrapFileGroup* scrapGroup = MgFindAttribute(element, "$scrap-group")->scrapFileGroup;
                resetExportedFlags(scrapGroup->nameGroup);
            }
            break;

        default:
            break;
        }
    }

    void resetExportedFlagsImplRec(
        MgScrap*      scrap,
        MgElement*    firstElement)
    {
        for( MgElement* element = firstElement; element; element = element->next )
            resetExportedFlagsImpl( scrap, element );
    }

    void resetExportedFlagsImpl(
        MgScrap*      scrap )
    {
        resetExportedFlagsImplRec(scrap, scrap->body);
    }

    void resetExportedFlagsImpl(
        MgScrapFileGroup* fileGroup)
    {
        MgScrap* scrap = fileGroup->firstScrap;
        while( scrap )
        {
            resetExportedFlagsImpl( scrap );
            scrap = scrap->next;
        }
    }

    void resetExportedFlags(
        MgScrapNameGroup* nameGroup)
    {
        nameGroup->hasBeenExported = false;

        MgScrapFileGroup* fileGroup = nameGroup->firstFileGroup;
        while( fileGroup )
        {
            resetExportedFlagsImpl( fileGroup );
            fileGroup = fileGroup->next;
        }
    }

    void exportScrapNameGroupOnce(
        MgContext*        context,
        MgScrapNameGroup* nameGroup,
        MgWriter*         writer )
    {
        if(!nameGroup->hasBeenExported)
        {
            ExportScrapNameGroupImpl(context, nameGroup, writer);
            nameGroup->hasBeenExported = true;
        }
    }

    void ExportScrapFileGroup(
        MgContext*        context,
        MgScrapFileGroup* fileGroup,
        MgWriter*         writer )
    {
        MgScrapKind kind = fileGroup->nameGroup->kind;
        if(kind == kScrapKind_Unknown)
        {
            kind = context->defaultScrapKind;
        }

        switch( kind )
        {
        default:
            assert(0);
            break;

        case kScrapKind_GlobalMacro:
        case kScrapKind_RawMacro:
        case kScrapKind_OutputFile:
            ExportScrapNameGroupImpl(context, fileGroup->nameGroup, writer);
            break;

        case kScrapKind_LocalMacro:
            ExportScrapFileGroupImpl(context, fileGroup, writer);
            break;

        case kScrapKind_OnceMacro:
            exportScrapNameGroupOnce(context, fileGroup->nameGroup, writer);
            break;
        }
    }

    void writeOutputPath(
        MgContext*          context,
        MgScrapNameGroup*   codeFile,
        MgWriter*           writer)
    {
        // if we have an output path, write it first...
        auto sourcePath = context->options->sourceOutputPath;
        if(sourcePath)
        {
            MgWriteCString(writer, sourcePath);
        }

        MgString id = codeFile->id;
        MgWriteString(writer, id);
    }

    void MgWriteCodeFile(
        MgContext*          context,
        MgScrapNameGroup*   codeFile )
    {
        MgString id = codeFile->id;

        // We want to construct the name of the file to write
        int pathSize = 0;
        MgWriter pathWriter;
        MgInitializeCountingWriter( &pathWriter, &pathSize );
        writeOutputPath(context, codeFile, &pathWriter);

        char* pathBuffer = (char*) malloc(pathSize + 1);
        char const* outputPath = pathBuffer;
        pathBuffer[pathSize] = 0;

        MgInitializeMemoryWriter( &pathWriter, pathBuffer );
        writeOutputPath(context, codeFile, &pathWriter);

        MgWriter writer;

        // now construct the outputString
        int counter = 0;
        MgInitializeCountingWriter( &writer, &counter );
        ExportScrapNameGroupImpl( context, codeFile, &writer );

        int outputSize = counter;
        char* outputBuffer = (char*) malloc(outputSize + 1);
        outputBuffer[outputSize] = 0;

        resetExportedFlags( codeFile );
        
        MgInitializeMemoryWriter( &writer, outputBuffer );
        ExportScrapNameGroupImpl( context, codeFile, &writer );

        MgString outputText = MgMakeString( outputBuffer, outputBuffer + outputSize );
        MgWriteTextToFile(outputText, outputPath);
    }
