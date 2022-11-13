unit ucore;

interface

uses
  Windows, Messages, Variants, Graphics, Controls, FileCtrl,
  Dialogs, StdCtrls,  Classes, SysUtils, Forms,
  DB, ZConnection, ZAbstractRODataset, ZAbstractDataset, ZDataset, ZSqlProcessor,
  ADODb, DBTables,
  udatatypes_apps,
  // Classes
  ClassParametrosDeEntrada,
  ClassArquivoIni, ClassStrings, ClassConexoes, ClassConf, ClassMySqlBases,
  ClassTextFile, ClassDirectory, ClassLog, ClassFuncoesWin, ClassLayoutArquivo,
  ClassFuncoesBancarias, ClassPlanoDeTriagem, ClassExpressaoRegular,
  ClassStatusProcessamento, ClassDateTime, ClassSMTPDelphi;

type

  TCore = class(TObject)
  private

    __queryMySQL_processamento__    : TZQuery;
    __queryMySQL_processamento2__   : TZQuery;
    __queryMySQL_Update__           : TZQuery;
    __queryMySQL_Insert_            : TZQuery;
    __queryMySQL_plano_de_triagem__ : TZQuery;

    // FUNÇÃO DE PROCESSAMENTO
      Procedure PROCESSAMENTO();

      procedure StoredProcedure_Dropar(Nome: string; logBD:boolean=false; idprograma:integer=0);

      function StoredProcedure_Criar(Nome : string; scriptSQL: TStringList): boolean;

      procedure StoredProcedure_Executar(Nome: string; ComParametro:boolean=false; logBD:boolean=false; idprograma:integer=0);

      function Compactar_Arquivo_7z(Arquivo, destino : String; mover_arquivo: Boolean=false): integer;
      function Extrair_Arquivo_7z(Arquivo, destino : String): integer;

      PROCEDURE COMPACTAR_ARQUIVO(ARQUIVO_ORIGEM, PATH_DESTINO: String; MOVER_ARQUIVO: Boolean=FALSE);
      PROCEDURE EXTRAIR_ARQUIVO(ARQUIVO_ORIGEM, PATH_DESTINO: String);

      procedure Atualiza_arquivo_conf_C(ArquivoConf, sINP, sOUT, sTMP, sLOG, sRGP: String);
      procedure execulta_app_c(app, arquivo_conf: string);

  public

    __ListaPlanoDeTriagem__       : TRecordPlanoTriagemCorreios;

    objParametrosDeEntrada   : TParametrosDeEntrada;
    objConexao               : TMysqlDatabase;
    objPlanoDeTriagem        : TPlanoDeTriagem;
    objString                : TFormataString;
    objLogar                 : TArquivoDelog;
    objDateTime              : TFormataDateTime;
    objArquivoIni            : TArquivoIni;
    objArquivoDeConexoes     : TArquivoDeConexoes;
    objArquivoDeConfiguracao : TArquivoConf;
    objDiretorio             : TDiretorio;
    objFuncoesWin            : TFuncoesWin;
    objLayoutArquivoCliente  : TLayoutCliente;
    objFuncoesBancarias      : TFuncoesBancarias;
    objExpressaoRegular      : TExpressaoRegular;
    objStatusProcessamento   : TStausProcessamento;
    objEmail                 : TSMTPDelphi;

    PROCEDURE COMPACTAR();
    PROCEDURE EXTRAIR();

    function GERA_LOTE_PEDIDO(): String;
    Procedure VALIDA_LOTE_PEDIDO();
    Procedure AtualizaDadosTabelaLOG();

    function PesquisarLote(LOTE_PEDIDO : STRING; status : Integer): Boolean;

    procedure ExcluirBase(NomeTabela: String);
    procedure ExcluirTabela(NomeTabela: String);
    function EnviarEmail(Assunto: string=''; Corpo: string=''): Boolean;
    procedure MainLoop();
    constructor create();

    procedure ReverterArquivos();

    procedure getListaDeArquivosJaProcessados();

    function ArquivoExieteTabelaTrack(sValue: string): Boolean;
    function ArquivoExieteTabelaTrackLine(sValue: string): Boolean;
    function ArquivoExieteTabelaTrackLineHistory(sValue: string): Boolean;
    procedure ProcessaMovimento();

    procedure getListaDeTabelasTrackLine();
    procedure getListaDeLotesMovimento();


  end;

implementation

uses uMain, Math;

constructor TCore.create();
var
  sMSG                       : string;
  sArquivosScriptSQL         : string;
  stlScripSQL                : TStringList;
begin

  try

    stlScripSQL                                               := TStringList.Create();

    objStatusProcessamento                                    := TStausProcessamento.create();
    objParametrosDeEntrada                                    := TParametrosDeEntrada.Create();

    objParametrosDeEntrada.STL_LISTA_ARQUIVOS_JA_PROCESSADOS  := TStringList.Create();
    objParametrosDeEntrada.STL_LISTA_ARQUIVOS_REVERTER        := TStringList.Create();
    objParametrosDeEntrada.STL_LISTA_LOTES                    := TStringList.Create();
    objParametrosDeEntrada.STL_LISTA_TABELAS_TRACK_LINE       := TStringList.Create();

    objLogar                                                  := TArquivoDelog.Create();
    if FileExists(objLogar.getArquivoDeLog()) then
      objFuncoesWin.DelFile(objLogar.getArquivoDeLog());

    objFuncoesWin                        := TFuncoesWin.create(objLogar);
    objString                            := TFormataString.Create(objLogar);
    objDateTime                          := TFormataDateTime.Create(objLogar);
    objLayoutArquivoCliente              := TLayoutCliente.Create();
    objFuncoesBancarias                  := TFuncoesBancarias.Create();
    objExpressaoRegular                  := TExpressaoRegular.Create();

    objArquivoIni                        := TArquivoIni.create(objLogar,
                                                               objString,
                                                               ExtractFilePath(Application.ExeName),
                                                               ExtractFileName(Application.ExeName));

    objArquivoDeConexoes                 := TArquivoDeConexoes.create(objLogar,
                                                                      objString,
                                                                      objArquivoIni.getPathConexoes());

    objArquivoDeConfiguracao             := TArquivoConf.create(objArquivoIni.getPathConfiguracoes(),
                                                                ExtractFileName(Application.ExeName));

    objParametrosDeEntrada.ID_PROCESSAMENTO := objArquivoDeConfiguracao.getIDProcessamento;

    objConexao                           := TMysqlDatabase.Create();

    if objArquivoIni.getPathConfiguracoes() <> '' then
    begin

      objParametrosDeEntrada.PATHENTRADA                                := objArquivoDeConfiguracao.getConfiguracao('path_default_arquivos_entrada');
      objParametrosDeEntrada.PATHSAIDA                                  := objArquivoDeConfiguracao.getConfiguracao('path_default_arquivos_saida');
      objParametrosDeEntrada.TABELA_PROCESSAMENTO                       := objArquivoDeConfiguracao.getConfiguracao('TABELA_PROCESSAMENTO');
      objParametrosDeEntrada.TABELA_PROCESSAMENTO2                      := objArquivoDeConfiguracao.getConfiguracao('TABELA_PROCESSAMENTO2');
      objParametrosDeEntrada.TABELA_LOTES_PEDIDOS                       := objArquivoDeConfiguracao.getConfiguracao('TABELA_LOTES_PEDIDOS');
      objParametrosDeEntrada.TABELA_PLANO_DE_TRIAGEM                    := objArquivoDeConfiguracao.getConfiguracao('tabela_plano_de_triagem');
      objParametrosDeEntrada.CARREGAR_PLANO_DE_TRIAGEM_MEMORIA          := objArquivoDeConfiguracao.getConfiguracao('CARREGAR_PLANO_DE_TRIAGEM_MEMORIA');
      objParametrosDeEntrada.LIMITE_DE_SELECT_POR_INTERACOES_NA_MEMORIA := objArquivoDeConfiguracao.getConfiguracao('numero_de_select_por_interacoes_na_memoria');
      objParametrosDeEntrada.FORMATACAO_LOTE_PEDIDO                     := objArquivoDeConfiguracao.getConfiguracao('FORMATACAO_LOTE_PEDIDO');
      objParametrosDeEntrada.lista_de_caracteres_invalidos              := objArquivoDeConfiguracao.getConfiguracao('lista_de_caracteres_invalidos');
      objParametrosDeEntrada.eHost                                      := objArquivoDeConfiguracao.getConfiguracao('eHost');
      objParametrosDeEntrada.eUser                                      := objArquivoDeConfiguracao.getConfiguracao('eUser');
      objParametrosDeEntrada.eFrom                                      := objArquivoDeConfiguracao.getConfiguracao('eFrom');
      objParametrosDeEntrada.eTo                                        := objArquivoDeConfiguracao.getConfiguracao('eTo');

      objParametrosDeEntrada.EXTENCAO_ARQUIVOS                          := objArquivoDeConfiguracao.getConfiguracao('EXTENCAO_ARQUIVOS');

      objParametrosDeEntrada.GERAR_MODELOS                              := objArquivoDeConfiguracao.getConfiguracao('GERAR_MODELOS');
      objParametrosDeEntrada.NUMERO_DE_MODELOS                          := objArquivoDeConfiguracao.getConfiguracao('NUMERO_DE_MODELOS');

      objParametrosDeEntrada.COPIAR_LOG_PARA_SAIDA                      := StrToBool(objArquivoDeConfiguracao.getConfiguracao('COPIAR_LOG_PARA_SAIDA'));

      objParametrosDeEntrada.OF_FORMULARIO                              := objArquivoDeConfiguracao.getConfiguracao('OF_FORMULARIO');
      objParametrosDeEntrada.PESO_PAPEL                                 := objArquivoDeConfiguracao.getConfiguracao('PESO_PAPEL');
      objParametrosDeEntrada.ACABAMENTO                                 := objArquivoDeConfiguracao.getConfiguracao('ACABAMENTO');
      objParametrosDeEntrada.PAPEL                                      := objArquivoDeConfiguracao.getConfiguracao('PAPEL');

      objParametrosDeEntrada.CRIAR_CSV_TRACK                            := StrTobool(objArquivoDeConfiguracao.getConfiguracao('CRIAR_CSV_TRACK'));
      objParametrosDeEntrada.PATH_TRACK                                 := objArquivoDeConfiguracao.getConfiguracao('PATH_TRACK');

      objParametrosDeEntrada.TABELA_TRACK_LINES                         := objArquivoDeConfiguracao.getConfiguracao('TABELA_TRACK_LINES');

      objParametrosDeEntrada.TABELA_TRACK                               := objArquivoDeConfiguracao.getConfiguracao('TABELA_TRACK');
      objParametrosDeEntrada.TABELA_TRACK_LINE                          := objArquivoDeConfiguracao.getConfiguracao('TABELA_TRACK_LINE');
      objParametrosDeEntrada.TABELA_TRACK_LINE_HISTORY                  := objArquivoDeConfiguracao.getConfiguracao('TABELA_TRACK_LINE_HISTORY');

      objParametrosDeEntrada.APP_C_GERA_SPOOL_EXE                       := objArquivoDeConfiguracao.getConfiguracao('APP_C_GERA_SPOOL_EXE');
      objParametrosDeEntrada.APP_C_GERA_SPOOL_CFG                       := objArquivoDeConfiguracao.getConfiguracao('APP_C_GERA_SPOOL_CFG');

      objParametrosDeEntrada.app_7z_32bits                              := objArquivoDeConfiguracao.getConfiguracao('app_7z_32bits');
      objParametrosDeEntrada.app_7z_64bits                              := objArquivoDeConfiguracao.getConfiguracao('app_7z_64bits');
      objParametrosDeEntrada.ARQUITETURA_WINDOWS                        := objArquivoDeConfiguracao.getConfiguracao('ARQUITETURA_WINDOWS');

      objParametrosDeEntrada.LOGAR                                      := objArquivoDeConfiguracao.getConfiguracao('LOGAR');

      //================
      //  LOGA USUÁRIO
      //========================================================================================================================================================
      objParametrosDeEntrada.APP_LOGAR                                  := objArquivoDeConfiguracao.getConfiguracao('APP_LOGAR');
      objParametrosDeEntrada.TABELA_LOTES_PEDIDOS_LOGIN                 := objArquivoDeConfiguracao.getConfiguracao('TABELA_LOTES_PEDIDOS_LOGIN');
      //========================================================================================================================================================

      objParametrosDeEntrada.ENVIAR_EMAIL                               := objArquivoDeConfiguracao.getConfiguracao('ENVIAR_EMAIL');



      objLogar.Logar('[DEBUG] TfrmMain.FormCreate() - Versão do programa: ' + objFuncoesWin.GetVersaoDaAplicacao());

      objParametrosDeEntrada.PathArquivo_TMP := objArquivoIni.getPathArquivosTemporarios();

      // Criando a Conexao
      objConexao.ConectarAoBanco(objArquivoDeConexoes.getHostName,
                                 'mysql',
                                 objArquivoDeConexoes.getUser,
                                 objArquivoDeConexoes.getPassword,
                                 objArquivoDeConexoes.getProtocolo
                                 );

      sArquivosScriptSQL := ExtractFileName(Application.ExeName);
      sArquivosScriptSQL := StringReplace(sArquivosScriptSQL, '.exe', '.sql', [rfReplaceAll, rfIgnoreCase]);

      stlScripSQL.LoadFromFile(objArquivoIni.getPathScripSQL() + sArquivosScriptSQL);
      objConexao.ExecutaScript(stlScripSQL);

      // Criando Objeto de Plano de Triagem
      if StrToBool(objParametrosDeEntrada.CARREGAR_PLANO_DE_TRIAGEM_MEMORIA) then
        objPlanoDeTriagem := TPlanoDeTriagem.create(objConexao,
                                                    objLogar,
                                                    objString,
                                                    objParametrosDeEntrada.TABELA_PLANO_DE_TRIAGEM, fac);



      objParametrosDeEntrada.stlRelatorioQTDE           := TStringList.Create();

      // LISTA DE ARUQIVOS JA PROCESSADOS
      getListaDeArquivosJaProcessados();


      objParametrosDeEntrada.STL_LOG_TXT                := TStringList.Create(); 

      IF StrToBool(objParametrosDeEntrada.LOGAR) THEN
      BEGIN

          //================
          //  LOGA USUÁRIO
          //==========================================================================================================================================================
          objParametrosDeEntrada.APP_LOGAR_PARAMETRO_TAB_INDEX      := '2';
          objParametrosDeEntrada.APP_LOGAR_PARAMETRO_NOME_APLICACAO := StringReplace(ExtractFileName(Application.ExeName), '.EXE', '', [rfReplaceAll, rfIgnoreCase]);
          objParametrosDeEntrada.APP_LOGAR_PARAMETRO_ARQUIVO_LOGAR  := ExtractFilePath(Application.ExeName) +
                                                                       StringReplace(ExtractFileName(objParametrosDeEntrada.APP_LOGAR), '.EXE', '.TXT', [rfReplaceAll, rfIgnoreCase]);

          objParametrosDeEntrada.APP_LOGAR_PARAMETRO_ARQUIVO_LOGAR  := StringReplace(objParametrosDeEntrada.APP_LOGAR_PARAMETRO_ARQUIVO_LOGAR, '\', '/', [rfReplaceAll, rfIgnoreCase]);

          

          objParametrosDeEntrada.STL_ARQUIVO_USUARIO_LOGADO := TStringList.Create();
          objFuncoesWin.ExecutarPrograma(objParametrosDeEntrada.APP_LOGAR
                                 + ' ' + objParametrosDeEntrada.APP_LOGAR_PARAMETRO_TAB_INDEX
                                 + ' ' + objParametrosDeEntrada.APP_LOGAR_PARAMETRO_NOME_APLICACAO
                                 + ' ' + objParametrosDeEntrada.APP_LOGAR_PARAMETRO_ARQUIVO_LOGAR);

          objParametrosDeEntrada.STL_ARQUIVO_USUARIO_LOGADO.LoadFromFile(objParametrosDeEntrada.APP_LOGAR_PARAMETRO_ARQUIVO_LOGAR);

          //=====================
          //   CAMPOS DE LOGIN
          //=====================
          objParametrosDeEntrada.USUARIO_LOGADO_APP           := objString.getTermo(1, ';', objParametrosDeEntrada.STL_ARQUIVO_USUARIO_LOGADO.Strings[0]);
          objParametrosDeEntrada.APP_LOGAR_CHAVE_APP          := objString.getTermo(2, ';', objParametrosDeEntrada.STL_ARQUIVO_USUARIO_LOGADO.Strings[0]);
          objParametrosDeEntrada.APP_LOGAR_LOTE               := objString.getTermo(3, ';', objParametrosDeEntrada.STL_ARQUIVO_USUARIO_LOGADO.Strings[0]);
          objParametrosDeEntrada.APP_LOGAR_USUARIO_LOGADO_WIN := objString.getTermo(4, ';', objParametrosDeEntrada.STL_ARQUIVO_USUARIO_LOGADO.Strings[0]);
          objParametrosDeEntrada.APP_LOGAR_IP                 := objString.getTermo(5, ';', objParametrosDeEntrada.STL_ARQUIVO_USUARIO_LOGADO.Strings[0]);
          objParametrosDeEntrada.APP_LOGAR_ID                 := objString.getTermo(6, ';', objParametrosDeEntrada.STL_ARQUIVO_USUARIO_LOGADO.Strings[0]);

          IF (Trim(objParametrosDeEntrada.USUARIO_LOGADO_APP) ='')
          or (Trim(objParametrosDeEntrada.APP_LOGAR_CHAVE_APP) ='')
          or (Trim(objParametrosDeEntrada.APP_LOGAR_LOTE) ='')
          or (Trim(objParametrosDeEntrada.APP_LOGAR_USUARIO_LOGADO_WIN) ='')
          or (Trim(objParametrosDeEntrada.APP_LOGAR_IP) ='')
          or (Trim(objParametrosDeEntrada.APP_LOGAR_ID) ='')
          THEN
            objParametrosDeEntrada.USUARIO_LOGADO_APP := '-1';
      END;

      //=========================
      //    DADOS DE REDE APP
      //=========================
      objParametrosDeEntrada.HOSTNAME                     := objFuncoesWin.getNetHostName;
      objParametrosDeEntrada.IP                           := objFuncoesWin.GetIP;
      objParametrosDeEntrada.USUARIO_SO                   := objFuncoesWin.GetUsuarioLogado;

      //========================
      //  GERA LOTE PEDIDO
      //========================
      if NOT StrToBool(objParametrosDeEntrada.LOGAR) then
      BEGIN

        objParametrosDeEntrada.PEDIDO_LOTE                  := GERA_LOTE_PEDIDO();

        objParametrosDeEntrada.USUARIO_LOGADO_APP           := objParametrosDeEntrada.USUARIO_SO;
        objParametrosDeEntrada.APP_LOGAR_CHAVE_APP          := objParametrosDeEntrada.ID_PROCESSAMENTO;
        objParametrosDeEntrada.APP_LOGAR_LOTE               := objParametrosDeEntrada.PEDIDO_LOTE;
        objParametrosDeEntrada.APP_LOGAR_USUARIO_LOGADO_WIN := objParametrosDeEntrada.USUARIO_SO;
        objParametrosDeEntrada.APP_LOGAR_IP                 := objParametrosDeEntrada.IP;
        objParametrosDeEntrada.APP_LOGAR_ID                 := objParametrosDeEntrada.ID_PROCESSAMENTO;

      END
      ELSE
      IF objParametrosDeEntrada.USUARIO_LOGADO_APP <> '-1' THEN
        objParametrosDeEntrada.PEDIDO_LOTE                := GERA_LOTE_PEDIDO();
      //==========================================================================================================================================================

    end;

  except
    on E:Exception do
    begin

      sMSG := '[ERRO] Não foi possível inicializar as configurações aq do programa. '+#13#10#13#10
            + ' EXCEÇÃO: '+E.Message+#13#10#13#10
            + ' O programa será encerrado agora.';

      showmessage(sMSG);

      objLogar.Logar(sMSG);

      Application.Terminate;
    end;
  end;

end;

function TCore.GERA_LOTE_PEDIDO(): String;
var
  sComando : string;
  sData    : string;
begin

  //==================
  //  CRIA NOVO LOTE
  //==================
  sData := FormatDateTime('YYYY-MM-DD hh:mm:ss', Now());

  sComando := ' insert into ' + objParametrosDeEntrada.TABELA_LOTES_PEDIDOS + '(VALIDO, DATA_CRIACAO, CHAVE, USUARIO_WIN, USUARIO_APP, IP, ID, LOTE_LOGIN, HOSTNAME)'
            + ' Value('
                      + '"'   + 'N'
                      + '","' + sData
                      + '","' + objParametrosDeEntrada.APP_LOGAR_CHAVE_APP
                      + '","' + objParametrosDeEntrada.APP_LOGAR_USUARIO_LOGADO_WIN
                      + '","' + objParametrosDeEntrada.USUARIO_LOGADO_APP
                      + '","' + objParametrosDeEntrada.APP_LOGAR_IP
                      + '","' + objParametrosDeEntrada.ID_PROCESSAMENTO
                      + '","' + objParametrosDeEntrada.APP_LOGAR_LOTE
                      + '","' + objParametrosDeEntrada.HOSTNAME
                      + '")';
  objConexao.Executar_SQL(__queryMySQL_processamento__, sComando, 1);

  //========================
  //  RETORNA LOTE CRIADO
  //========================
  sComando := ' SELECT LOTE_PEDIDO FROM  ' + objParametrosDeEntrada.TABELA_LOTES_PEDIDOS
            + ' WHERE '
                      + '     VALIDO        = "' + 'N'                                                 + '"'
                      + ' AND DATA_CRIACAO  = "' + sData                                               + '"'
                      + ' AND CHAVE         = "' + objParametrosDeEntrada.APP_LOGAR_CHAVE_APP          + '"'
                      + ' AND USUARIO_WIN   = "' + objParametrosDeEntrada.APP_LOGAR_USUARIO_LOGADO_WIN + '"'
                      + ' AND USUARIO_APP   = "' + objParametrosDeEntrada.USUARIO_LOGADO_APP           + '"'
                      + ' AND HOSTNAME      = "' + objParametrosDeEntrada.HOSTNAME                     + '"'
                      + ' AND LOTE_LOGIN    = "' + objParametrosDeEntrada.APP_LOGAR_LOTE               + '"'
                      + ' AND IP            = "' + objParametrosDeEntrada.APP_LOGAR_IP                 + '"'
                      + ' AND ID            = "' + objParametrosDeEntrada.ID_PROCESSAMENTO             + '"';
  objConexao.Executar_SQL(__queryMySQL_processamento__, sComando, 2);

  Result := FormatFloat(objParametrosDeEntrada.FORMATACAO_LOTE_PEDIDO, __queryMySQL_processamento__.FieldByName('LOTE_PEDIDO').AsInteger);

end;

PROCEDURE TCore.VALIDA_LOTE_PEDIDO();
VAR
  sComando                : string;
BEGIN

  //========================
  //  RETORNA LOTE CRIADO
  //========================
  sComando := ' UPDATE  ' + objParametrosDeEntrada.TABELA_LOTES_PEDIDOS
            + ' set VALIDO         = "' + objParametrosDeEntrada.STATUS_PROCESSAMENTO  + '"'
            + '    ,RELATORIO_QTD  = "' + objParametrosDeEntrada.stlRelatorioQTDE.Text + '"'
            + '    ,LOTE_LOGIN     = "' + objParametrosDeEntrada.APP_LOGAR_LOTE    + '"'
            + ' WHERE '
            + '     LOTE_PEDIDO   = "' + objParametrosDeEntrada.PEDIDO_LOTE                   + '"'
            + ' AND VALIDO        = "' + 'N'                                                  + '"'
            + ' AND CHAVE         = "' + objParametrosDeEntrada.APP_LOGAR_CHAVE_APP           + '"'
            + ' AND USUARIO_WIN   = "' + objParametrosDeEntrada.APP_LOGAR_USUARIO_LOGADO_WIN  + '"'
            + ' AND HOSTNAME      = "' + objParametrosDeEntrada.HOSTNAME                      + '"'
            + ' AND IP            = "' + objParametrosDeEntrada.APP_LOGAR_IP                  + '"'
            + ' AND ID            = "' + objParametrosDeEntrada.ID_PROCESSAMENTO              + '"';
  objConexao.Executar_SQL(__queryMySQL_processamento__, sComando, 1);

end;

Procedure TCore.AtualizaDadosTabelaLOG();
var
  sComando                  : String;
Begin
  //=========================================================================
  //  GRAVA LOG NA TABELA DE LOGIN - SOMENTE SE O PARÂMETRO LOGAR FOR TRUE
  //=========================================================================
  if StrToBool(objParametrosDeEntrada.LOGAR) then
  begin
    objParametrosDeEntrada.STL_LOG_TXT.Text := StringReplace(objParametrosDeEntrada.STL_LOG_TXT.Text, '\', '\\', [rfReplaceAll, rfIgnoreCase]);

    sComando := ' update ' + objParametrosDeEntrada.TABELA_LOTES_PEDIDOS_LOGIN
              + ' SET '
              + '      LOG_APP          = "' + objParametrosDeEntrada.STL_LOG_TXT.Text                           + '"'
              + '     ,VALIDO           = "' + objParametrosDeEntrada.STATUS_PROCESSAMENTO                       + '"'
              + '     ,QTD_PROCESSADA   = "' + IntToStr(objParametrosDeEntrada.TOTAL_PROCESSADOS_LOG)            + '"'
              + '     ,QTD_INVALIDOS    = "' + IntToStr(objParametrosDeEntrada.TOTAL_PROCESSADOS_INVALIDOS_LOG)  + '"'
              + '     ,LOTE_APP         = "' + objParametrosDeEntrada.PEDIDO_LOTE                                + '"'
              + '     ,RELATORIO_QTD    = "' + objParametrosDeEntrada.stlRelatorioQTDE.Text                      + '"'
              + ' WHERE CHAVE       = "' + objParametrosDeEntrada.APP_LOGAR_CHAVE_APP          + '"'
              + '   AND LOTE_PEDIDO = "' + objParametrosDeEntrada.APP_LOGAR_LOTE               + '"'
              + '   AND USUARIO_WIN = "' + objParametrosDeEntrada.APP_LOGAR_USUARIO_LOGADO_WIN + '"'
              + '   AND USUARIO_APP = "' + objParametrosDeEntrada.USUARIO_LOGADO_APP           + '"'
              + '   AND HOSTNAME    = "' + objParametrosDeEntrada.HOSTNAME                     + '"'
              + '   AND IP          = "' + objParametrosDeEntrada.APP_LOGAR_IP                 + '"'
              + '   AND ID          = "' + objParametrosDeEntrada.APP_LOGAR_ID                 + '"';
    objConexao.Executar_SQL(__queryMySQL_processamento__, sComando, 1);
  end;

end;

procedure TCore.MainLoop();
var
  sMSG : string;
begin

  objLogar.Logar('[DEBUG] TCore.MainLoop() - begin...');
  try
    try

        objDiretorio := TDiretorio.create(objParametrosDeEntrada.PathEntrada);
        objParametrosDeEntrada.PathEntrada := objDiretorio.getDiretorio();

        objDiretorio.setDiretorio(objParametrosDeEntrada.PathSaida);
        objParametrosDeEntrada.PathSaida   := objDiretorio.getDiretorio();

//      PROCESSAMENTO();

    finally

      if Assigned(objDiretorio) then
      begin
        objDiretorio.destroy;
        Pointer(objDiretorio) := nil;
      end;

    end;

  except

    // 0------------------------------------------0
    // |  Excessões desntro do objCore caem aqui  |
    // 0------------------------------------------0
    on E:Exception do
    begin

      sMSG :='Erro ao execultar a Função MainLoop(). ' + #13#10#13#10
                 +'EXCEÇÃO: '+E.Message+#13#10#13#10
                 +'O programa será encerrado agora.';

      IF StrToBool(objParametrosDeEntrada.ENVIAR_EMAIL) THEN
        EnviarEmail('ERRO DE PROCESSAMENTO !!!', sMSG + #13 + #13 + 'SEGUE LOG EM ANEXO.' + #13 + #13
        + 'DETALHES DE LOGIN' + #13
        + '=================' + #13
        + 'HOSTNAME.......................: ' + objParametrosDeEntrada.HOSTNAME + #13
        + 'USUARIO LOGADO.................: ' + objParametrosDeEntrada.USUARIO_LOGADO_APP + #13
        + 'USUARIO SO.....................: ' + objParametrosDeEntrada.USUARIO_SO + #13
        + 'LOTE LOGIN.....................: ' + objParametrosDeEntrada.APP_LOGAR_LOTE + #13
        + 'IP.............................: ' + objParametrosDeEntrada.IP);

      showmessage(sMSG);
      objLogar.Logar(sMSG);

    end;
  end;

  objLogar.Logar('[DEBUG] TCore.MainLoop() - ...end');

end;

Procedure TCore.PROCESSAMENTO();
Var


Arq_Arquivo_Entada   : TextFile;
Arq_Arquivo_Saida    : TextFile;

sArquivoEntrada      : string;
sArquivoSaida        : string;
sLinha               : string;
sValues              : string;
sComando             : string;
sCampos              : string;
sOperadora           : string;
sContrato            : string;
sCep                 : string;

iContArquivos        : Integer;
iTotalDeArquivos     : Integer;

// Variáveis de controle do select
iTotalDeRegistrosDaTabela : Integer;
iLimit : Integer;
iTotalDeInteracoesDeSelects : Integer;
iResto : Integer;
iRegInicial : Integer;
iQtdeRegistros : Integer;
iContInteracoesDeSelects : Integer;


begin

  //*********************************************************************************************
  //                         Alimentando nome dos campos da tabela de Cliente
  //*********************************************************************************************
  sComando := 'describe ' + objParametrosDeEntrada.tabela_processamento;
  objStatusProcessamento := objConexao.Executar_SQL(__queryMySQL_processamento__, sComando, 2);

  while not __queryMySQL_processamento__.Eof do
  Begin
    sCampos := sCampos + __queryMySQL_processamento__.FieldByName('Field').AsString;
    __queryMySQL_processamento__.Next;
    if not __queryMySQL_processamento__.Eof then
      sCampos := sCampos + ',';
  end;

  iTotalDeArquivos := objParametrosDeEntrada.ListaDeArquivosDeEntrada.Count;

  for iContArquivos := 0 to iTotalDeArquivos - 1 do
  begin

    sComando := 'delete from ' + objParametrosDeEntrada.tabela_processamento;
    objStatusProcessamento := objConexao.Executar_SQL(__queryMySQL_processamento__, sComando, 1);

    sArquivoEntrada := objParametrosDeEntrada.ListaDeArquivosDeEntrada.Strings[iContArquivos];

    AssignFile(Arq_Arquivo_Entada, objString.AjustaPath(objParametrosDeEntrada.PathEntrada) + sArquivoEntrada);
    reset(Arq_Arquivo_Entada);

    while not eof(Arq_Arquivo_Entada) do
    Begin

      readln(Arq_Arquivo_Entada, sLinha);

      sLinha := objString.StringReplaceList(sLinha, objParametrosDeEntrada.lista_de_caracteres_invalidos);

      sOperadora := Copy(sLinha, 16, 3);
      sContrato  := Copy(sLinha, 23, 9);
      sCep       := Copy(sLinha, 393, 8);

      sValues := '"' + sOperadora + '",'
               + '"' + sContrato + '",'
               + '"' + sCep + '",'
               + '"' + sLinha + '"';

      sComando := 'Insert into ' + objParametrosDeEntrada.tabela_processamento + ' (' + sCampos + ') values(' + sValues + ')';
      objStatusProcessamento := objConexao.Executar_SQL(__queryMySQL_processamento__, sComando, 1);

    end;

    CloseFile(Arq_Arquivo_Entada);

    sComando := 'SELECT count(contrato) as qtde FROM ' + objParametrosDeEntrada.tabela_processamento;
    objStatusProcessamento := objConexao.Executar_SQL(__queryMySQL_processamento__, sComando, 2);

    iTotalDeRegistrosDaTabela := __queryMySQL_processamento__.FieldByName('qtde').AsInteger;

    iLimit := StrToInt(objParametrosDeEntrada.LIMITE_DE_SELECT_POR_INTERACOES_NA_MEMORIA);
    iResto := iTotalDeRegistrosDaTabela mod iLimit;

    if iResto <> 0 then
      iTotalDeInteracoesDeSelects := iTotalDeRegistrosDaTabela div iLimit + 1
    else
      iTotalDeInteracoesDeSelects := iTotalDeRegistrosDaTabela div iLimit;

    iQtdeRegistros := 0;

    sArquivoSaida   := StringReplace(sArquivoEntrada, '.txt', '_SAIDA.TXT', [rfReplaceAll, rfIgnoreCase]);

    AssignFile(Arq_Arquivo_Saida, objString.AjustaPath(objParametrosDeEntrada.PATHSAIDA) + sArquivoSaida);
    Rewrite(Arq_Arquivo_Saida);

    for iContInteracoesDeSelects := 0 to iTotalDeInteracoesDeSelects -1 do
    begin
      iRegInicial    := iQtdeRegistros;
      iQtdeRegistros := iQtdeRegistros + iLimit;

      sComando := 'SELECT * FROM ' + objParametrosDeEntrada.tabela_processamento + ' limit ' + IntToStr(iRegInicial) + ',' + IntToStr(iLimit);
      objStatusProcessamento := objConexao.Executar_SQL(__queryMySQL_processamento__, sComando, 2);

      while not __queryMySQL_processamento__.Eof do
      begin

        sLinha := __queryMySQL_processamento__.FieldByName('LINHA').AsString;

        sCep   := Copy(sLinha, 393, 8);

        writeln(Arq_Arquivo_Saida, sLinha);

        __queryMySQL_processamento__.Next;

      end;

    end;

    CloseFile(Arq_Arquivo_Saida);

  end;

end;

procedure TCore.ExcluirBase(NomeTabela: String);
var
  sComando : String;
  sBase    : string;
begin

  sBase := objString.getTermo(1, '.', NomeTabela);

  sComando := 'drop database ' + sBase;
  objStatusProcessamento := objConexao.Executar_SQL(__queryMySQL_processamento__, sComando, 1);
end;

procedure TCore.ExcluirTabela(NomeTabela: String);
var
  sComando : String;
  sTabela  : String;
begin

  sTabela := objString.getTermo(2, '.', NomeTabela);

  sComando := 'drop table ' + sTabela;
  objStatusProcessamento := objConexao.Executar_SQL(__queryMySQL_processamento__, sComando, 1);
end;


procedure TCore.StoredProcedure_Dropar(Nome: string; logBD:boolean=false; idprograma:integer=0);
var
  sSQL: string;
  sMensagem: string;
begin
  try
    sSQL := 'DROP PROCEDURE if exists ' + Nome;
    objConexao.Executar_SQL(__queryMySQL_processamento__, sSQL, 1);
  except
    on E:Exception do
    begin
      sMensagem := '  StoredProcedure_Dropar(' + Nome + ') - Excecao:' + E.Message + ' . SQL: ' + sSQL;
      objLogar.Logar(sMensagem);
    end;
  end;

end;

function TCore.StoredProcedure_Criar(Nome : string; scriptSQL: TStringList): boolean;
var
  bExecutou    : boolean;
  sMensagem    : string;
begin


  bExecutou := objConexao.Executar_SQL(__queryMySQL_processamento__, scriptSQL.Text, 1).status;

  if not bExecutou then
  begin
    sMensagem := '  StoredProcedure_Criar(' + Nome + ') - Não foi possível carregar a stored procedure para execução.';
    objLogar.Logar(sMensagem);
  end;

  result := bExecutou;
end;

procedure TCore.StoredProcedure_Executar(Nome: string; ComParametro:boolean=false; logBD:boolean=false; idprograma:integer=0);
var

  sSQL        : string;
  sMensagem   : string;
begin

  try
    (*
    if not Assigned(con) then
    begin
      con := TZConnection.Create(Application);
      con.HostName  := objConexao.getHostName;
      con.Database  := sNomeBase;
      con.User      := objConexao.getUser;
      con.Protocol  := objConexao.getProtocolo;
      con.Password  := objConexao.getPassword;
      con.Properties.Add('CLIENT_MULTI_STATEMENTS=1');
      con.Connected := True;
    end;

    if not Assigned(QP) then
      QP := TZQuery.Create(Application);

    QP.Connection := con;
    QP.SQL.Clear;
    *)

    sSQL := 'CALL '+ Nome;
    if not ComParametro then
      sSQL := sSQL + '()';

    objConexao.Executar_SQL(__queryMySQL_processamento__, sSQL, 1);

  except
    on E:Exception do
    begin
      sMensagem := '[ERRO] StoredProcedure_Executar('+Nome+') - Excecao:'+E.Message+' . SQL: '+sSQL;
      objLogar.Logar(sMensagem);
      ShowMessage(sMensagem);
    end;
  end;

//  objConexao.Executar_SQL(__queryMySQL_processamento__, sSQL, 1)

end;

function TCore.EnviarEmail(Assunto: string=''; Corpo: string=''): Boolean;
var
  sHost    : string;
  suser    : string;
  sFrom    : string;
  sTo      : string;
  sAssunto : string;
  sCorpo   : string;
  sAnexo   : string;
  sAplicacao: string;

begin

  sAplicacao := ExtractFileName(Application.ExeName);
  sAplicacao := StringReplace(sAplicacao, '.exe', '', [rfReplaceAll, rfIgnoreCase]);

  sHost    := objParametrosDeEntrada.eHost;
  suser    := objParametrosDeEntrada.eUser;
  sFrom    := objParametrosDeEntrada.eFrom;
  sTo      := objParametrosDeEntrada.eTo;
  sAssunto := 'Processamento - ' + sAplicacao + ' - ' + objFuncoesWin.GetVersaoDaAplicacao() + ' [PROCESSAMENTO: ' + objParametrosDeEntrada.PEDIDO_LOTE + ']';
  sAssunto := sAssunto + ' ' + Assunto;
  sCorpo   := Corpo;

  sAnexo := objLogar.getArquivoDeLog();

  //sAnexo := StringReplace(anexo, '"', '', [rfReplaceAll, rfIgnoreCase]);
  //sAnexo := StringReplace(anexo, '''', '', [rfReplaceAll, rfIgnoreCase]);

  try

    objEmail := TSMTPDelphi.create(sHost, suser);

    if objEmail.ConectarAoServidorSMTP() then
    begin
      if objEmail.AnexarArquivo(sAnexo) then
      begin

          if not (objEmail.EnviarEmail(sFrom, sTo, sAssunto, sCorpo)) then
            ShowMessage('ERRO AO ENVIAR O E-MAIL')
          else
          if not objEmail.DesconectarDoServidorSMTP() then
            ShowMessage('ERRO AO DESCONECTAR DO SERVIDOR');
      end
      else
        ShowMessage('ERRO AO ANEXAR O ARQUIVO');
    end
    else
      ShowMessage('ERRO AO CONECTAR AO SERVIDOR');

  except
    ShowMessage('NÃO FOI POSSIVEL ENVIAR O E-MAIL.');
  end;
end;



function Tcore.PesquisarLote(LOTE_PEDIDO : STRING; status : Integer): Boolean;
var
  sComando : string;
  iPedido  : Integer;
  sStauts  : string;
begin

  case status of
    0: sStauts := 'S';
    1: sStauts := 'N';
  end;

  objParametrosDeEntrada.PEDIDO_LOTE_TMP := LOTE_PEDIDO;

  sComando := ' SELECT RELATORIO_QTD FROM  ' + objParametrosDeEntrada.TABELA_LOTES_PEDIDOS
            + ' WHERE LOTE_PEDIDO = ' + LOTE_PEDIDO + ' AND VALIDO = "' + sStauts + '"';
  objStatusProcessamento := objConexao.Executar_SQL(__queryMySQL_processamento__, sComando, 2);

  objParametrosDeEntrada.stlRelatorioQTDE.Text := __queryMySQL_processamento__.FieldByName('RELATORIO_QTD').AsString;

  if __queryMySQL_processamento__.RecordCount > 0 then
    Result := True
  else
    Result := False;

end;

PROCEDURE TCORE.COMPACTAR();
Var
  sArquivo         : String;
  sPathEntrada     : String;
  sPathSaida       : String;

  iContArquivos    : Integer;
  iTotalDeArquivos : Integer;
BEGIN

  sPathEntrada := objString.AjustaPath(objParametrosDeEntrada.PATHENTRADA);
  sPathSaida   := objString.AjustaPath(objParametrosDeEntrada.PATHSAIDA);
  ForceDirectories(sPathSaida);

  iTotalDeArquivos := objParametrosDeEntrada.ListaDeArquivosDeEntrada.Count;

  for iContArquivos := 0 to iTotalDeArquivos - 1 do
  begin

    sArquivo := objParametrosDeEntrada.LISTADEARQUIVOSDEENTRADA.Strings[iContArquivos];
    COMPACTAR_ARQUIVO(sPathEntrada + sArquivo, sPathSaida, True);

  end;

end;

PROCEDURE TCORE.EXTRAIR();
Var
  sArquivo         : String;
  sPathEntrada     : String;
  sPathSaida       : String;

  iContArquivos    : Integer;
  iTotalDeArquivos : Integer;
BEGIN

  sPathEntrada := objString.AjustaPath(objParametrosDeEntrada.PATHENTRADA);
  sPathSaida   := objString.AjustaPath(objParametrosDeEntrada.PATHSAIDA);
  ForceDirectories(sPathSaida);

  iTotalDeArquivos := objParametrosDeEntrada.ListaDeArquivosDeEntrada.Count;

  for iContArquivos := 0 to iTotalDeArquivos - 1 do
  begin

    sArquivo := objParametrosDeEntrada.LISTADEARQUIVOSDEENTRADA.Strings[iContArquivos];
    EXTRAIR_ARQUIVO(sPathEntrada + sArquivo, sPathSaida);

  end;

end;


PROCEDURE TCORE.COMPACTAR_ARQUIVO(ARQUIVO_ORIGEM, PATH_DESTINO: String; MOVER_ARQUIVO: Boolean = FALSE);
begin

  Compactar_Arquivo_7z(ARQUIVO_ORIGEM, PATH_DESTINO, MOVER_ARQUIVO);

end;

PROCEDURE TCORE.EXTRAIR_ARQUIVO(ARQUIVO_ORIGEM, PATH_DESTINO: String);
begin

  Extrair_Arquivo_7z(ARQUIVO_ORIGEM, PATH_DESTINO);

end;

function TCORE.Compactar_Arquivo_7z(Arquivo, destino : String; mover_arquivo: Boolean=false): integer;
Var
  sComando                  : String;
  sArquivoDestino           : String;
  sParametros               : String;
  __AplicativoCompactacao__ : String;

  iRetorno                  : Integer;
Begin

    sArquivoDestino := ExtractFileName(Arquivo) + '.7Z';

    destino := objString.AjustaPath(destino);

    sParametros := ' a ';

    IF StrToInt(objParametrosDeEntrada.ARQUITETURA_WINDOWS) = 32 THEN
      __AplicativoCompactacao__ := objParametrosDeEntrada.app_7z_32bits;

    IF StrToInt(objParametrosDeEntrada.ARQUITETURA_WINDOWS) = 64 THEN
      __AplicativoCompactacao__ := objParametrosDeEntrada.app_7z_64bits;

    sComando := __AplicativoCompactacao__ + sParametros + ' "' + destino + sArquivoDestino + '" "' + Arquivo + '"';

    if mover_arquivo then
      sComando := sComando + ' -sdel';

    iRetorno := objFuncoesWin.WinExecAndWait32(sComando);

    Result   := iRetorno;

End;

function TCORE.Extrair_Arquivo_7z(Arquivo, destino : String): integer;
Var
  sComando                  : String;
  sParametros               : String;
  __AplicativoCompactacao__ : String;

  iRetorno                  : Integer;
Begin

    destino := objString.AjustaPath(destino);

    sParametros := ' e ';

    IF StrToInt(objParametrosDeEntrada.ARQUITETURA_WINDOWS) = 32 THEN
      __AplicativoCompactacao__ := objParametrosDeEntrada.app_7z_32bits;

    IF StrToInt(objParametrosDeEntrada.ARQUITETURA_WINDOWS) = 64 THEN
      __AplicativoCompactacao__ := objParametrosDeEntrada.app_7z_64bits;

    sComando := __AplicativoCompactacao__ + sParametros + ' ' + Arquivo +  ' -y -o"' + destino + '"';

    iRetorno := objFuncoesWin.WinExecAndWait32(sComando);

    Result   := iRetorno;

End;

procedure TCore.ProcessaMovimento();
var

  txtSaida                          : TextFile;
  txtSaidaModelos                   : TextFile;
  stlIDXModelos                     : TStringList;


  sPathEntrada                      : string;

  sPathMovimentoPedido              : string;
  sPathMovimentoIDX                 : string;
  sPathMovimentoIDX_Modelos         : string;
  sPathMovimentoAFP                 : string;
  sPathMovimentoAFP_Modelos         : string;

  sPathMovimentoArquivos            : string;
  sPathMovimentoBackupZip           : string;
  sPathMovimentoCIF                 : string;
  sPathMovimentoRelatorio           : string;
  sPathComplemento                  : string;
  sPathMovimentoTRACK               : string;
  sPathMovimentoTMP                 : string;
  sArquivoDOC                       : string;
  sArquivoDOC_Modelos               : string;
  sArquivoZIP                       : string;
  sArquivoPDF                       : string;
  sArquivoTXT                       : string;
  sArquivoJRN                       : string;
  sArquivoAFP                       : string;
  sArquivoAFP_DOC                   : string;
  sArquivoAFP_DOC_Modelos           : string;
  sArquivoIDX                       : string;
  sArquivoIDX_Modelos               : string;
  sArquivoREL                       : string;
  sComando                          : string;
  sLinha                            : string;
  sLinhaTrackLineOrigem             : string;

  sDirecao                          : string;
  sCategoria                        : string;
  sPorte                            : string;
  sCep                              : string;

  sProdutoCarne                     : string;
  iStatusCodigo                     : Integer;
  sStatusCodigo                     : string;
  sStatusLabel                      : string;

  sLote                             : string;
  sPostagem                         : string;
  sTipoDocumento                    : string;
  sTabelaTrack                      : string;
  sARQUIVO_ORIGEM_BANCO              : string;
  sDTA_REFERENCIA                    : string;

  iContLotes                        : Integer;
  iContArquivos                     : Integer;
  iContArquivoZip                   : Integer;
  iTotalFolhas                      : Integer;
  iTotalPaginas                     : Integer;
  iTotalObjestos                    : Integer;
  iContLinas                        : Integer;

  iContTabelasTrackline             : Integer;


  stlFiltroArquivo                  : TStringList;
  stlRelatorio                      : TStringList;
  stlTrack                          : TStringList;

begin

  objParametrosDeEntrada.TIMESTAMP := now();

  stlFiltroArquivo                 := TStringList.create();
  stlRelatorio                     := TStringList.create();
  stlTrack                         := TStringList.create();
  stlIDXModelos                    := TStringList.Create();

  //=======================================================================================================================================================================================
  //  LIMPANDO A TABELA DE PROCESSAMENTO
  //=======================================================================================================================================================================================
  sComando := 'DELETE FROM ' + objParametrosDeEntrada.TABELA_PROCESSAMENTO;
  objConexao.Executar_SQL(__queryMySQL_processamento__, sComando, 1);

  sComando := 'DELETE FROM ' + objParametrosDeEntrada.TABELA_PROCESSAMENTO2;
  objConexao.Executar_SQL(__queryMySQL_processamento__, sComando, 1);
  //=======================================================================================================================================================================================

  if objParametrosDeEntrada.TESTE then
    sPathComplemento := '_TESTE';


  //=======================================================================================================================================================================================
  //  DEFINE ESTRUTURA MOVIMENTO
  //=======================================================================================================================================================================================
  sPathEntrada                     := objString.AjustaPath(objParametrosDeEntrada.PATHENTRADA);


  sPathMovimentoArquivos           := objString.AjustaPath(objParametrosDeEntrada.PATHSAIDA) + FormatDateTime('YYYYMMDD', objParametrosDeEntrada.MOVIMENTO) + PathDelim;
  //sPathMovimentoArquivos           := objString.AjustaPath(objParametrosDeEntrada.PATHSAIDA) + FormatDateTime('YYYYMMDD', objParametrosDeEntrada.MOVIMENTO) + sPathComplemento + PathDelim + FormatFloat(objParametrosDeEntrada.FORMATACAO_LOTE_PEDIDO, StrToInt(objParametrosDeEntrada.PEDIDO_LOTE)) + PathDelim + 'ARQUIVOS'   + PathDelim;
  //sPathmovimentoBackupZip          := objString.AjustaPath(objParametrosDeEntrada.PATHSAIDA) + FormatDateTime('YYYYMMDD', objParametrosDeEntrada.MOVIMENTO) + sPathComplemento + PathDelim + FormatFloat(objParametrosDeEntrada.FORMATACAO_LOTE_PEDIDO, StrToInt(objParametrosDeEntrada.PEDIDO_LOTE)) + PathDelim + 'BACKUP_ZIP' + PathDelim;
  //sPathmovimentoCIF                := objString.AjustaPath(objParametrosDeEntrada.PATHSAIDA) + FormatDateTime('YYYYMMDD', objParametrosDeEntrada.MOVIMENTO) + sPathComplemento + PathDelim + FormatFloat(objParametrosDeEntrada.FORMATACAO_LOTE_PEDIDO, StrToInt(objParametrosDeEntrada.PEDIDO_LOTE)) + PathDelim + 'CIF'        + PathDelim;
  //sPathMovimentoTRACK              := objString.AjustaPath(objParametrosDeEntrada.PATHSAIDA) + FormatDateTime('YYYYMMDD', objParametrosDeEntrada.MOVIMENTO) + sPathComplemento + PathDelim + FormatFloat(objParametrosDeEntrada.FORMATACAO_LOTE_PEDIDO, StrToInt(objParametrosDeEntrada.PEDIDO_LOTE)) + PathDelim + 'TRACK'      + PathDelim;
  //sPathMovimentoTMP                := objString.AjustaPath(objParametrosDeEntrada.PATHSAIDA) + FormatDateTime('YYYYMMDD', objParametrosDeEntrada.MOVIMENTO) + sPathComplemento + PathDelim + FormatFloat(objParametrosDeEntrada.FORMATACAO_LOTE_PEDIDO, StrToInt(objParametrosDeEntrada.PEDIDO_LOTE)) + PathDelim + 'TMP'      + PathDelim;
  //=======================================================================================================================================================================================

  //===================================================================================================================================================================
  // CRIA PASTAS
  //===================================================================================================================================================================
  ForceDirectories(sPathMovimentoArquivos);
  //ForceDirectories(sPathmovimentoCIF);
  //ForceDirectories(sPathMovimentoTRACK);
  //ForceDirectories(sPathMovimentoTMP);
  //===================================================================================================================================================================

  //===================================================================================================================================================================
  // ARQUIVOS SELECIONADOS
  //===================================================================================================================================================================
  iContLinas := 0;
  for iContLotes := 0 to objParametrosDeEntrada.LISTADEARQUIVOSDEENTRADA.Count - 1 do
  begin

    sLinha      := objParametrosDeEntrada.LISTADEARQUIVOSDEENTRADA.Strings[iContLotes];

    sLote          := objString.getTermo(3, ' - ', sLinha);
    sPostagem      := objString.getTermo(2, ' - ', sLinha);
    sTipoDocumento := objString.getTermo(4, ' - ', sLinha);
    sTabelaTrack   := objString.getTermo(6, ' - ', sLinha);

    sLote          := Trim(StringReplace(sLote,          'LOTE: '          , '', [rfReplaceAll, rfIgnoreCase]));
    sPostagem      := Trim(StringReplace(sPostagem,      'POSTAGEM: '      , '', [rfReplaceAll, rfIgnoreCase]));
    sTipoDocumento := Trim(StringReplace(sTipoDocumento, 'TIPO DOCUMENTO: ', '', [rfReplaceAll, rfIgnoreCase]));
    sTabelaTrack   := Trim(StringReplace(sTabelaTrack,   'TBL: '           , '', [rfReplaceAll, rfIgnoreCase]));

      //=======================================================================================================================================
      //  PEGA O NOME DO ARQUIVO ZIP NA TABELA DE TRACK LINE
      //=======================================================================================================================================
      sComando := 'SELECT * FROM ' + sTabelaTrack
                + ' WHERE LOTE           = "' + sLote + '" '
                + '   AND DATA_POSTAGEM  = "' + sPostagem + '" '
                + '   AND TIPO_DOCUMENTO = "' + sTipoDocumento + '" ';
      objConexao.Executar_SQL(__queryMySQL_processamento__, sComando, 2);

    WHILE NOT __queryMySQL_processamento__.Eof DO
    BEGIN

      iContLinas            := iContLinas + 1;

      sLinhaTrackLineOrigem := __queryMySQL_processamento__.FieldByName('LINHA').AsString;

      //=================================================================================================================================================================
      //  INSERE NA TABELA PROCESSAMENTO
      //=================================================================================================================================================================

      if sTipoDocumento = 'CARNE' then
      begin

        sProdutoCarne := copy(sLinhaTrackLineOrigem, 24, 3);

        sStatusCodigo := __queryMySQL_processamento__.FieldByName('STATUS_REGISTRO').AsString;

        sStatusLabel  := 'IMPRESSAO';
        iStatusCodigo := StrToIntDef(sStatusCodigo, 0);

        if sProdutoCarne = '120' then
          sStatusLabel  := 'IMPRESSAO/PDF';

        if iStatusCodigo = 5 then
          sStatusLabel := 'RETENÇÃO';

        if (iStatusCodigo = 2) or (iStatusCodigo = 3) or (iStatusCodigo = 4) then
          sStatusLabel := 'CEP INCONSISTENTE';

        sComando := 'INSERT INTO  ' + objParametrosDeEntrada.TABELA_PROCESSAMENTO
                   + ' (SEQUENCIA'
                   + ' ,N_CONTRATO'
                   + ' ,N_CHASSI'
                   + ' ,CPF_CNPJ_CLIENTE'
                   + ' ,NOME_CLIENTE'
                   + ' ,VALOR_CARNE'
                   + ' ,QTD_PARCELAS'
                   + ' ,DT_VENCIMENTO'
                   + ' ,STATUS'
                   + ' ,CODIGO_POSTAGEM_CORREIOS'
                   + ' ,ENDERECO'
                   + ' ,BAIRRO'
                   + ' ,CIDADE'
                   + ' ,UF'
                   + ' ,CEP'
                   + ' ,ARQUIVO_ORIGEM_BANCO'
                   + ' ,DTA_REFERENCIA'
                   + ' ,CIF'
                   + ') '
                   + ' VALUES("' + IntToStr(iContLinas)
                         + '","' + Trim(copy(__queryMySQL_processamento__.FieldByName('LINHA').AsString, 0020, 016))
                         + '","' + Trim(copy(__queryMySQL_processamento__.FieldByName('LINHA').AsString, 2168, 020))
                         + '","' + Trim(copy(__queryMySQL_processamento__.FieldByName('LINHA').AsString, 0594, 014))
                         + '","' + Trim(copy(__queryMySQL_processamento__.FieldByName('LINHA').AsString, 0101, 030))
                         + '","' + Trim(copy(__queryMySQL_processamento__.FieldByName('LINHA').AsString, 1814, 015))
                         + '","' + Trim(copy(__queryMySQL_processamento__.FieldByName('LINHA').AsString, 0500, 003))
                         + '","' + Trim(copy(__queryMySQL_processamento__.FieldByName('LINHA').AsString, 0047, 008))
                         + '","' + sStatusLabel
                         + '","' + Trim(copy(__queryMySQL_processamento__.FieldByName('LINHA').AsString, 1899, 034))
                         + '","' + Trim(copy(__queryMySQL_processamento__.FieldByName('LINHA').AsString, 0713, 060))
                         + '","' + Trim(copy(__queryMySQL_processamento__.FieldByName('LINHA').AsString, 0808, 030))
                         + '","' + Trim(copy(__queryMySQL_processamento__.FieldByName('LINHA').AsString, 0838, 030))
                         + '","' + Trim(copy(__queryMySQL_processamento__.FieldByName('LINHA').AsString, 0868, 002))
                         + '","' + Trim(copy(__queryMySQL_processamento__.FieldByName('LINHA').AsString, 0870, 008))
                         + '","' + Trim(copy(__queryMySQL_processamento__.FieldByName('LINHA').AsString, 2034, 013))
                         + '","' + __queryMySQL_processamento__.FieldByName('MOVIMENTO').AsString
                         + '","' + __queryMySQL_processamento__.FieldByName('CIF').AsString
                         + '")';
        objConexao.Executar_SQL(__queryMySQL_Insert_, sComando, 1);

        //=================================================================================================================================================================
        //  INSERE NA TABELA TRACK LINE
        //=================================================================================================================================================================
        if not objParametrosDeEntrada.TESTE then
        begin
          sComando := 'INSERT INTO  ' + objParametrosDeEntrada.TABELA_TRACK_LINE
                    + ' (ARQUIVO_ZIP'
                     + ',ARQUIVO_AFP'
                     + ',ARQUIVO_TXT'
                     + ',SEQUENCIA_REGISTRO'
                     + ',TIMESTAMP'
                     + ',LOTE_PROCESSAMENTO'
                     + ',MOVIMENTO'
                     + ',ACABAMENTO'
                     + ',PAGINAS'
                     + ',FOLHAS'
                     + ',OF_FORMULARIO'
                     + ',DATA_POSTAGEM'
                     + ',LOTE'
                     + ',CIF'
                     + ',PESO'
                     + ',DIRECAO'
                     + ',CATEGORIA'
                     + ',PORTE'
                     + ',STATUS_REGISTRO'
                     + ',PAPEL'
                     + ',TIPO_DOCUMENTO'
                     + ',LINHA'
                     + ') '
                     + ' VALUES("'
                     +         __queryMySQL_processamento__.FieldByName('ARQUIVO_ZIP').AsString
                     + '","' + __queryMySQL_processamento__.FieldByName('ARQUIVO_AFP').AsString
                     + '","' + __queryMySQL_processamento__.FieldByName('ARQUIVO_TXT').AsString
                     + '","' + __queryMySQL_processamento__.FieldByName('SEQUENCIA_REGISTRO').AsString
                     + '","' + FormatDateTime('YYYY-MM-DD hh:mm:ss', objParametrosDeEntrada.TIMESTAMP)
                     + '","' + __queryMySQL_processamento__.FieldByName('LOTE_PROCESSAMENTO').AsString
                     + '","' + __queryMySQL_processamento__.FieldByName('MOVIMENTO').AsString
                     + '","' + __queryMySQL_processamento__.FieldByName('ACABAMENTO').AsString
                     + '","' + __queryMySQL_processamento__.FieldByName('PAGINAS').AsString
                     + '","' + __queryMySQL_processamento__.FieldByName('FOLHAS').AsString
                     + '","' + __queryMySQL_processamento__.FieldByName('OF_FORMULARIO').AsString
                     + '","' + __queryMySQL_processamento__.FieldByName('DATA_POSTAGEM').AsString
                     + '","' + __queryMySQL_processamento__.FieldByName('LOTE').AsString
                     + '","' + __queryMySQL_processamento__.FieldByName('CIF').AsString
                     + '","' + __queryMySQL_processamento__.FieldByName('PESO').AsString
                     + '","' + __queryMySQL_processamento__.FieldByName('DIRECAO').AsString
                     + '","' + __queryMySQL_processamento__.FieldByName('CATEGORIA').AsString
                     + '","' + __queryMySQL_processamento__.FieldByName('PORTE').AsString
                     + '","' + __queryMySQL_processamento__.FieldByName('STATUS_REGISTRO').AsString
                     + '","' + __queryMySQL_processamento__.FieldByName('PAPEL').AsString
                     + '","' + __queryMySQL_processamento__.FieldByName('TIPO_DOCUMENTO').AsString
                     + '","' + __queryMySQL_processamento__.FieldByName('LINHA').AsString
                     + '")'
                     ;
          objConexao.Executar_SQL(__queryMySQL_Insert_, sComando, 1);

        END;

      end;

      __queryMySQL_processamento__.Next;

    end;
    //=======================================================================================================================================

  end;

  //=======================================================================================================================================
  //  CRIA SAÍDA DO RELATÓRIO DIÁRIO PARA IMPRESSAO/PDF
  //=======================================================================================================================================
  sComando := ' SELECT ARQUIVO_ORIGEM_BANCO, DTA_REFERENCIA  FROM ' + objParametrosDeEntrada.TABELA_PROCESSAMENTO
            + ' WHERE STATUS = "IMPRESSAO/PDF" '
            + ' GROUP BY DTA_REFERENCIA ';
  objConexao.Executar_SQL(__queryMySQL_processamento__, sComando, 2);

  IF __queryMySQL_processamento__.RecordCount > 0 THEN
  Begin

    sARQUIVO_ORIGEM_BANCO := Trim(__queryMySQL_processamento__.FieldByName('ARQUIVO_ORIGEM_BANCO').AsString);

    while not __queryMySQL_processamento__.Eof do
    begin

      sDTA_REFERENCIA := Trim(__queryMySQL_processamento__.FieldByName('DTA_REFERENCIA').AsString);

      sArquivoTXT     := 'RELATORIO_' + sARQUIVO_ORIGEM_BANCO + '_' + sDTA_REFERENCIA + '.CSV';

      ForceDirectories(sPathMovimentoArquivos + 'IMPRESSAO_PDF' + PathDelim);

      AssignFile(txtSaida, sPathMovimentoArquivos + 'IMPRESSAO_PDF' + PathDelim + sArquivoTXT);
      Rewrite(txtSaida);

      sLinha := '"N_CONTRATO"'
             + ';"N_CHASSI"'
             + ';"CPF/CNPJ CLIENTE"'
             + ';"NOME CLIENTE"'
             + ';"VALOR CARNE"'
             + ';"QTD PARCELAS"'
             + ';"DT VENCIMENTO"'
             + ';"STATUS"'
             + ';"CODIGO POSTAGEM CORREIOS"'
             + ';"ENDEREÇO"'
             + ';"BAIRRO"'
             + ';"CIDADE"'
             + ';"UF"'
             + ';"CEP"'
             + ';"ARQUIVO"'
             + ';"DTA_REFERENCIA"'
             ;
      writeln(txtSaida, sLinha);

      //=======================================================================================================================================
      //  CRIA SAÍDA DO RELATÓRIO DIÁRIO DETALHES [IMPRESSAO/PDF]
      //=======================================================================================================================================
      sComando := ' SELECT *  FROM ' + objParametrosDeEntrada.TABELA_PROCESSAMENTO
                + ' WHERE STATUS          = "IMPRESSAO/PDF" '
                + '   AND DTA_REFERENCIA  = "' + sDTA_REFERENCIA + '"';
      objConexao.Executar_SQL(__queryMySQL_processamento2__, sComando, 2);

      WHILE NOT __queryMySQL_processamento2__.Eof DO
      BEGIN

        sLinha := '"' + __queryMySQL_processamento2__.FieldByName('N_CONTRATO').AsString
              + '";"' + __queryMySQL_processamento2__.FieldByName('N_CHASSI').AsString
              + '";"' + __queryMySQL_processamento2__.FieldByName('CPF_CNPJ_CLIENTE').AsString
              + '";"' + __queryMySQL_processamento2__.FieldByName('NOME_CLIENTE').AsString
              + '";"' + __queryMySQL_processamento2__.FieldByName('VALOR_CARNE').AsString
              + '";"' + __queryMySQL_processamento2__.FieldByName('QTD_PARCELAS').AsString
              + '";"' + __queryMySQL_processamento2__.FieldByName('DT_VENCIMENTO').AsString
              + '";"' + __queryMySQL_processamento2__.FieldByName('STATUS').AsString
              + '";"' + __queryMySQL_processamento2__.FieldByName('CODIGO_POSTAGEM_CORREIOS').AsString
              + '";"' + __queryMySQL_processamento2__.FieldByName('ENDERECO').AsString
              + '";"' + __queryMySQL_processamento2__.FieldByName('BAIRRO').AsString
              + '";"' + __queryMySQL_processamento2__.FieldByName('CIDADE').AsString
              + '";"' + __queryMySQL_processamento2__.FieldByName('UF').AsString
              + '";"' + __queryMySQL_processamento2__.FieldByName('CEP').AsString
              + '";"' + __queryMySQL_processamento2__.FieldByName('ARQUIVO_ORIGEM_BANCO').AsString
              + '";"' + __queryMySQL_processamento2__.FieldByName('DTA_REFERENCIA').AsString
              +   '"';

        writeln(txtSaida, sLinha);

        //=================================================================
        //  ATUALIZANDO A LINHA DO RELATÓRIO NA TABELA DE HISTÓRICO
        //=================================================================
        if not objParametrosDeEntrada.TESTE then
        begin

          sComando := ' UPDATE ' + objParametrosDeEntrada.TABELA_TRACK_LINE
                    + ' SET LINHA_REL = "' + StringReplace(sLinha, '"', '\"', [rfReplaceAll, rfIgnoreCase]) + '"'
                    + ' WHERE CIF = "' + __queryMySQL_processamento2__.FieldByName('CIF').AsString + '"';

          objConexao.Executar_SQL(__queryMySQL_Update__, sComando, 1);

        END;
        //=================================================================

        __queryMySQL_processamento2__.Next;
      END;

      CloseFile(txtSaida);

      __queryMySQL_processamento__.Next;

    END;

  END;


  //=======================================================================================================================================
  //  CRIA SAÍDA DO RELATÓRIO DIÁRIO COM TUDO
  //=======================================================================================================================================
  sComando := ' SELECT ARQUIVO_ORIGEM_BANCO, DTA_REFERENCIA  FROM ' + objParametrosDeEntrada.TABELA_PROCESSAMENTO
            //+ ' WHERE STATUS <> "IMPRESSAO/PDF" '
            + ' GROUP BY DTA_REFERENCIA ';
  objConexao.Executar_SQL(__queryMySQL_processamento__, sComando, 2);


  IF __queryMySQL_processamento__.RecordCount > 0 THEN
  Begin

    sARQUIVO_ORIGEM_BANCO := Trim(__queryMySQL_processamento__.FieldByName('ARQUIVO_ORIGEM_BANCO').AsString);

    while not __queryMySQL_processamento__.Eof do
    begin


      sDTA_REFERENCIA       := Trim(__queryMySQL_processamento__.FieldByName('DTA_REFERENCIA').AsString);

      sArquivoTXT           := 'RELATORIO_' + sARQUIVO_ORIGEM_BANCO + '_' + sDTA_REFERENCIA + '.CSV';

      AssignFile(txtSaida, sPathMovimentoArquivos + sArquivoTXT);
      Rewrite(txtSaida);

      sLinha := '"N_CONTRATO"'
             + ';"N_CHASSI"'
             + ';"CPF/CNPJ CLIENTE"'
             + ';"NOME CLIENTE"'
             + ';"VALOR CARNE"'
             + ';"QTD PARCELAS"'
             + ';"DT VENCIMENTO"'
             + ';"STATUS"'
             + ';"CODIGO POSTAGEM CORREIOS"'
             + ';"ENDEREÇO"'
             + ';"BAIRRO"'
             + ';"CIDADE"'
             + ';"UF"'
             + ';"CEP"'
             + ';"ARQUIVO"'
             + ';"DTA_REFERENCIA"'
             ;
      writeln(txtSaida, sLinha);

      //=======================================================================================================================================
      //  CRIA SAÍDA DO RELATÓRIO DIÁRIO DETALHES
      //=======================================================================================================================================
      sComando := ' SELECT *  FROM ' + objParametrosDeEntrada.TABELA_PROCESSAMENTO
                //+ ' WHERE STATUS              <> "IMPRESSAO/PDF" '
                //+ '   AND DTA_REFERENCIA       = "' + sDTA_REFERENCIA + '"';
                + ' WHERE DTA_REFERENCIA       = "' + sDTA_REFERENCIA + '"';

      objConexao.Executar_SQL(__queryMySQL_processamento2__, sComando, 2);

      WHILE NOT __queryMySQL_processamento2__.Eof DO
      BEGIN

        sLinha := '"' + __queryMySQL_processamento2__.FieldByName('N_CONTRATO').AsString
              + '";"' + __queryMySQL_processamento2__.FieldByName('N_CHASSI').AsString
              + '";"' + __queryMySQL_processamento2__.FieldByName('CPF_CNPJ_CLIENTE').AsString
              + '";"' + __queryMySQL_processamento2__.FieldByName('NOME_CLIENTE').AsString
              + '";"' + __queryMySQL_processamento2__.FieldByName('VALOR_CARNE').AsString
              + '";"' + __queryMySQL_processamento2__.FieldByName('QTD_PARCELAS').AsString
              + '";"' + __queryMySQL_processamento2__.FieldByName('DT_VENCIMENTO').AsString
              + '";"' + __queryMySQL_processamento2__.FieldByName('STATUS').AsString
              + '";"' + __queryMySQL_processamento2__.FieldByName('CODIGO_POSTAGEM_CORREIOS').AsString
              + '";"' + __queryMySQL_processamento2__.FieldByName('ENDERECO').AsString
              + '";"' + __queryMySQL_processamento2__.FieldByName('BAIRRO').AsString
              + '";"' + __queryMySQL_processamento2__.FieldByName('CIDADE').AsString
              + '";"' + __queryMySQL_processamento2__.FieldByName('UF').AsString
              + '";"' + __queryMySQL_processamento2__.FieldByName('CEP').AsString
              + '";"' + __queryMySQL_processamento2__.FieldByName('ARQUIVO_ORIGEM_BANCO').AsString
              + '";"' + __queryMySQL_processamento2__.FieldByName('DTA_REFERENCIA').AsString
              +   '"';

        writeln(txtSaida, sLinha);

        //=================================================================
        //  ATUALIZANDO A LINHA DO RELATÓRIO NA TABELA DE HISTÓRICO
        //=================================================================
        if not objParametrosDeEntrada.TESTE then
        begin

          sComando := ' UPDATE ' + objParametrosDeEntrada.TABELA_TRACK_LINE
                    + ' SET LINHA_REL = "' + StringReplace(sLinha, '"', '\"', [rfReplaceAll, rfIgnoreCase]) + '"'
                    + ' WHERE CIF = "' + __queryMySQL_processamento2__.FieldByName('CIF').AsString + '"';

          objConexao.Executar_SQL(__queryMySQL_Update__, sComando, 1);

        END;
        //=================================================================        

        __queryMySQL_processamento2__.Next;
      END;

      CloseFile(txtSaida);

      __queryMySQL_processamento__.Next;

    end;

  END;
  //=======================================================================================================================================

end;

procedure TCore.Atualiza_arquivo_conf_C(ArquivoConf, sINP, sOUT, sTMP, sLOG, sRGP: String);
var
  txtEntrada       : TextFile;
  sLinha           : string;
  sParametro       : string;
  stlArquivoConfC  : TStringList;
  sPathSaidaAFP    : string;
begin


  stlArquivoConfC := TStringList.Create();

  AssignFile(txtEntrada, ArquivoConf);
  Reset(txtEntrada);

  while not Eof(txtEntrada) do
  begin

    Readln(txtEntrada, sLinha);

    sParametro := AnsiUpperCase(Trim(objString.getTermo(1, '=', sLinha)));

    if sParametro = 'INP' then
      stlArquivoConfC.Add(sParametro + '=' + sINP);

    if sParametro = 'OUT' then
      stlArquivoConfC.Add(sParametro + '=' + sOUT);

    if sParametro = 'TMP' then
      stlArquivoConfC.Add(sParametro + '=' + sTMP);

    if sParametro = 'LOG' then
      stlArquivoConfC.Add(sParametro + '=' + sLOG);

    if sParametro = 'RGP' then
      stlArquivoConfC.Add(sParametro + '=' + sRGP);

  end;

  CloseFile(txtEntrada);

  stlArquivoConfC.SaveToFile(ArquivoConf);

end;

procedure TCore.execulta_app_c(app, arquivo_conf: string);
begin
  objFuncoesWin.ExecutarPrograma(app + ' "' + arquivo_conf + '"');
end;

function TCore.ArquivoExieteTabelaTrack(sValue: string): Boolean;
var
  sComando                            : string;
  sLinha                              : String;
  sLote                               : string;
  sPostagem                           : string;
  sTipoDocumento                      : string;
begin

  sLinha         := sValue;

  sLote          := objString.getTermo(3, ' - ', sLinha);
  sPostagem      := objString.getTermo(2, ' - ', sLinha);
  sTipoDocumento := objString.getTermo(4, ' - ', sLinha);

  sLote          := Trim(StringReplace(sLote,          'LOTE: '          , '', [rfReplaceAll, rfIgnoreCase]));
  sPostagem      := Trim(StringReplace(sPostagem,      'POSTAGEM: '      , '', [rfReplaceAll, rfIgnoreCase]));
  sTipoDocumento := Trim(StringReplace(sTipoDocumento, 'TIPO DOCUMENTO: ', '', [rfReplaceAll, rfIgnoreCase]));

  sComando := 'SELECT ARQUIVO_AFP FROM ' + objParametrosDeEntrada.TABELA_TRACK
            + ' WHERE LOTE           = "' + sLote + '" '
            + '   AND DATA_POSTAGEM  = "' + sPostagem + '" '
            + '   AND TIPO_DOCUMENTO = "' + sTipoDocumento + '" ';
  objConexao.Executar_SQL(__queryMySQL_processamento__, sComando, 2);

  if __queryMySQL_processamento__.RecordCount > 0 then
   Result := True
  else
    Result := False;

end;


function TCore.ArquivoExieteTabelaTrackLine(sValue: string): Boolean;
var
  sComando                            : string;
  sLinha                              : String;
  sLote                               : string;
  sPostagem                           : string;
  sTipoDocumento                      : string;
begin

  sLinha         := sValue;

  sLote          := objString.getTermo(3, ' - ', sLinha);
  sPostagem      := objString.getTermo(2, ' - ', sLinha);
  sTipoDocumento := objString.getTermo(4, ' - ', sLinha);

  sLote          := Trim(StringReplace(sLote,          'LOTE: '          , '', [rfReplaceAll, rfIgnoreCase]));
  sPostagem      := Trim(StringReplace(sPostagem,      'POSTAGEM: '      , '', [rfReplaceAll, rfIgnoreCase]));
  sTipoDocumento := Trim(StringReplace(sTipoDocumento, 'TIPO DOCUMENTO: ', '', [rfReplaceAll, rfIgnoreCase]));

  sComando := 'SELECT ARQUIVO_AFP FROM ' + objParametrosDeEntrada.TABELA_TRACK_LINE
            + ' WHERE LOTE           = "' + sLote + '" '
            + '   AND DATA_POSTAGEM  = "' + sPostagem + '" '
            + '   AND TIPO_DOCUMENTO = "' + sTipoDocumento + '" ';
  objConexao.Executar_SQL(__queryMySQL_processamento__, sComando, 2);

  if __queryMySQL_processamento__.RecordCount > 0 then
    Result := True
  else
    Result := False;

end;

function TCore.ArquivoExieteTabelaTrackLineHistory(sValue: string): Boolean;
var
  sComando                            : string;
  sLinha                              : String;
  sLote                               : string;
  sPostagem                           : string;
  sTipoDocumento                      : string;
begin

  sLinha         := sValue;

  sLote          := objString.getTermo(3, ' - ', sLinha);
  sPostagem      := objString.getTermo(2, ' - ', sLinha);
  sTipoDocumento := objString.getTermo(4, ' - ', sLinha);

  sLote          := Trim(StringReplace(sLote,          'LOTE: '          , '', [rfReplaceAll, rfIgnoreCase]));
  sPostagem      := Trim(StringReplace(sPostagem,      'POSTAGEM: '      , '', [rfReplaceAll, rfIgnoreCase]));
  sTipoDocumento := Trim(StringReplace(sTipoDocumento, 'TIPO DOCUMENTO: ', '', [rfReplaceAll, rfIgnoreCase]));

  sComando := 'SELECT ARQUIVO_AFP FROM ' + objParametrosDeEntrada.TABELA_TRACK_LINE_HISTORY
            + ' WHERE LOTE           = "' + sLote + '" '
            + '   AND DATA_POSTAGEM  = "' + sPostagem + '" '
            + '   AND TIPO_DOCUMENTO = "' + sTipoDocumento + '" ';
  objConexao.Executar_SQL(__queryMySQL_processamento__, sComando, 2);

  if __queryMySQL_processamento__.RecordCount > 0 then
    Result := True
  else
    Result := False;

end;


procedure TCore.getListaDeArquivosJaProcessados();
var
  sComando                   : string;
  sLinha                     : string;
begin

  sComando := ' SELECT * FROM ' + objParametrosDeEntrada.TABELA_TRACK_LINE
            + ' GROUP BY MOVIMENTO, LOTE, DATA_POSTAGEM '
            + ' ORDER BY MOVIMENTO, LOTE, DATA_POSTAGEM  DESC ';
  objConexao.Executar_SQL(__queryMySQL_processamento__, sComando, 2);

  objParametrosDeEntrada.STL_LISTA_ARQUIVOS_JA_PROCESSADOS.Clear;

  WHILE NOT __queryMySQL_processamento__.Eof do
  BEGIN

    sLinha := 'MOVIMENTO: '      + __queryMySQL_processamento__.FieldByName('MOVIMENTO').AsString
         + ' - POSTAGEM: '       + __queryMySQL_processamento__.FieldByName('DATA_POSTAGEM').AsString
         + ' - LOTE: '           + __queryMySQL_processamento__.FieldByName('LOTE').AsString
         + ' - TIPO DOCUMENTO: ' + __queryMySQL_processamento__.FieldByName('TIPO_DOCUMENTO').AsString;

    objParametrosDeEntrada.STL_LISTA_ARQUIVOS_JA_PROCESSADOS.Add(sLinha);

    __queryMySQL_processamento__.Next;
  end;

end;

procedure TCore.ReverterArquivos();
var
  iContArquivos                       : Integer;
  sLote                               : string;
  sPostagem                           : string;
  sTipoDocumento                      : string;
  sLinha                             : string;
  sComando                            : string;

begin

  for iContArquivos := 0 to objParametrosDeEntrada.STL_LISTA_ARQUIVOS_REVERTER.Count - 1 do
  begin

    sLinha := objParametrosDeEntrada.STL_LISTA_ARQUIVOS_REVERTER.Strings[iContArquivos];

    sLote          := objString.getTermo(3, ' - ', sLinha);
    sPostagem      := objString.getTermo(2, ' - ', sLinha);
    sTipoDocumento := objString.getTermo(4, ' - ', sLinha);

    sLote          := Trim(StringReplace(sLote,          'LOTE: '          , '', [rfReplaceAll, rfIgnoreCase]));
    sPostagem      := Trim(StringReplace(sPostagem,      'POSTAGEM: '      , '', [rfReplaceAll, rfIgnoreCase]));
    sTipoDocumento := Trim(StringReplace(sTipoDocumento, 'TIPO DOCUMENTO: ', '', [rfReplaceAll, rfIgnoreCase]));

    sComando := 'DELETE FROM ' + objParametrosDeEntrada.TABELA_TRACK_LINE
              + ' WHERE LOTE           = "' + sLote + '" '
              + '   AND DATA_POSTAGEM  = "' + sPostagem + '" '
              + '   AND TIPO_DOCUMENTO = "' + sTipoDocumento + '" ';

    objConexao.Executar_SQL(__queryMySQL_processamento__, sComando, 1);

    sComando := 'UPDATE ' + objParametrosDeEntrada.TABELA_TRACK
              + ' SET STATUS_ARQUIVO = 0'
              + ' WHERE LOTE           = "' + sLote + '" '
              + '   AND DATA_POSTAGEM  = "' + sPostagem + '" '
              + '   AND TIPO_DOCUMENTO = "' + sTipoDocumento + '" ';

    objConexao.Executar_SQL(__queryMySQL_processamento__, sComando, 1);

  end;

end;

procedure TCore.getListaDeLotesMovimento();
var
  sComando                           : string;
  sTabela                            : string;
  sLinha                             : string;
  iContTabelastrackLine              : Integer;

begin

  objParametrosDeEntrada.STL_LISTA_LOTES.Clear;
  for iContTabelastrackLine:= 0 to objParametrosDeEntrada.STL_LISTA_TABELAS_TRACK_LINE.Count -1 do
  begin

    sTabela := objParametrosDeEntrada.STL_LISTA_TABELAS_TRACK_LINE.Strings[iContTabelastrackLine];

    sComando := ' SELECT DATA_POSTAGEM, LOTE, TIPO_DOCUMENTO, MOVIMENTO FROM ' + sTabela
              + ' WHERE MOVIMENTO >= "' + FormatDateTime('YYYYMMDD', objParametrosDeEntrada.MOVIMENTO) + '" '
              + '   AND MOVIMENTO <= "' + FormatDateTime('YYYYMMDD', objParametrosDeEntrada.MOVIMENTO_FINAL) + '" '
              + ' GROUP BY DATA_POSTAGEM, LOTE, TIPO_DOCUMENTO, MOVIMENTO '
              + ' ORDER BY DATA_POSTAGEM, LOTE ';
    objConexao.Executar_SQL(__queryMySQL_processamento__, sComando, 2);


    WHILE NOT __queryMySQL_processamento__.Eof do
    begin

      sLinha := 'MOVIMENTO: ' + __queryMySQL_processamento__.FieldByName('MOVIMENTO').AsString
      + ' - POSTAGEM: '       + __queryMySQL_processamento__.FieldByName('DATA_POSTAGEM').AsString
      + ' - LOTE: '           + __queryMySQL_processamento__.FieldByName('LOTE').AsString
      + ' - TIPO DOCUMENTO: ' + __queryMySQL_processamento__.FieldByName('TIPO_DOCUMENTO').AsString
      + ' - ' + objString.AjustaStr(' ', 900) // FILLER
      + ' - TBL: ' + sTabela
      ;

      objParametrosDeEntrada.STL_LISTA_LOTES.Add(sLinha);

      __queryMySQL_processamento__.Next
    end;


  end;


end;

procedure TCore.getListaDeTabelasTrackLine();
var
  iContTabelas                       : Integer;
  iTotalTabelas                      : Integer;
  sTabela                            : string;
begin
  iTotalTabelas  := objString.GetNumeroOcorrenciasCaracter(objParametrosDeEntrada.TABELA_TRACK_LINES, ',') + 1;

  objParametrosDeEntrada.STL_LISTA_TABELAS_TRACK_LINE.Clear;
  for iContTabelas := 0 to iTotalTabelas-1 do
  begin

    sTabela := objString.getTermo(iContTabelas+1, ',', objParametrosDeEntrada.TABELA_TRACK_LINES);

    objParametrosDeEntrada.STL_LISTA_TABELAS_TRACK_LINE.Add(sTabela);

  end;
end;

end.
