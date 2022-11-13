CREATE DATABASE IF NOT EXISTS proj_touchgraf_delphi__relatorio_diario;

DROP TABLE IF EXISTS       proj_touchgraf_delphi__relatorio_diario.processamento;
CREATE TABLE IF NOT EXISTS proj_touchgraf_delphi__relatorio_diario.processamento (
   SEQUENCIA                  INTEGER  
  ,N_CONTRATO                 varchar(016) NOT NULL
  ,N_CHASSI                   varchar(020) NOT NULL
  ,CPF_CNPJ_CLIENTE           varchar(014) NOT NULL
  ,NOME_CLIENTE               varchar(030) NOT NULL
  ,VALOR_CARNE                varchar(015) NOT NULL
  ,QTD_PARCELAS               varchar(003) NOT NULL
  ,DT_VENCIMENTO              varchar(008) NOT NULL
  ,STATUS                     varchar(020) NOT NULL
  ,CODIGO_POSTAGEM_CORREIOS   varchar(034) NOT NULL
  ,ENDERECO                   varchar(060) NOT NULL
  ,BAIRRO                     varchar(030) NOT NULL
  ,CIDADE                     varchar(030) NOT NULL
  ,UF                         varchar(002) NOT NULL
  ,CEP                        varchar(008) NOT NULL
  ,ARQUIVO_ORIGEM_BANCO       varchar(013) NOT NULL
  ,DTA_REFERENCIA             varchar(008) NOT NULL
  ,CIF                        VARCHAR(34) NOT NULL
  ,PRIMARY KEY(SEQUENCIA),
  KEY IDX_CHAVE2 (ARQUIVO_ORIGEM_BANCO, DTA_REFERENCIA)
);

DROP TABLE IF EXISTS       proj_touchgraf_delphi__relatorio_diario.processamento2;
CREATE TABLE IF NOT EXISTS proj_touchgraf_delphi__relatorio_diario.processamento2 (
   LINHA                      TEXT
  ,SEQUENCIA                  INTEGER
  ,ARQUIVO_AFP                VARCHAR(050) default NULL
  ,ARQUIVO_ZIP                varchar(050) default NULL
  ,MOVIMENTO                  varchar(008) default NULL
  ,PRIMARY KEY(SEQUENCIA)

);

drop table if exists proj_touchgraf_delphi__relatorio_diario.tbl_entrada;
create table proj_touchgraf_delphi__relatorio_diario.tbl_entrada(
  seq int auto_increment,
  tipo_reg varchar(2),
  OPERADORA varchar(3),
  CONTRATO varchar(9),
  arquivo varchar(100),
  textolinha VARCHAR(959),
  PRIMARY KEY(seq)
);
/*CREATE INDEX idx_tbl_entrada ON proj_touchgraf_delphi__relatorio_diario.tbl_entrada (seq, tipo_reg, OPERADORA, CONTRATO, arquivo);*/


/*DROP TABLE IF EXISTS proj_touchgraf_delphi__relatorio_diario.controle_arquivos;*/
CREATE TABLE IF NOT EXISTS proj_touchgraf_delphi__relatorio_diario.controle_arquivos (
  LOTE                 int(10)      unsigned NOT NULL,
  DATA_INSERSAO        datetime              NOT NULL,
  ARQUIVO              varchar(100)          NOT NULL,
  PAGINAS              varchar(010)          NOT NULL,
  OBJETOS              varchar(010)          NOT NULL,
  PRIMARY KEY (LOTE, ARQUIVO),
  KEY idx_controle_arquivo (ARQUIVO)
);

CREATE TABLE IF NOT EXISTS proj_touchgraf_delphi__relatorio_diario.LOTES_PEDIDOS (
  LOTE_PEDIDO      int     NOT NULL auto_increment,
  VALIDO           CHAR(1) NOT NULL default 'N',

  DATA_CRIACAO     DATETIME,
  CHAVE            VARCHAR(17),
  ID               VARCHAR(17),
  USUARIO_WIN      VARCHAR(20),
  USUARIO_APP      VARCHAR(20),
  IP               VARCHAR(14),
  LOTE_LOGIN       INT,

  RELATORIO_QTD    MEDIUMBLOB,
  HOSTNAME         varchar(15),
  PRIMARY KEY  (LOTE_PEDIDO)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

CREATE TABLE IF NOT EXISTS proj_touchgraf_delphi__relatorio_diario.track (
  ARQUIVO_ZIP              VARCHAR(60) NOT NULL,
  ARQUIVO_AFP              VARCHAR(60) NOT NULL,
  ARQUIVO_TXT              VARCHAR(60) NOT NULL,
  LOTE                     INT(11) NOT NULL,
  DATA_POSTAGEM          VARCHAR(10) NOT NULL,
  TIMESTAMP                DATETIME NOT NULL,
  LINHAS                   INT(11) NOT NULL DEFAULT '0',
  OBJETOS                  INT(11) NOT NULL DEFAULT '0',
  FOLHAS                   INT(11) NOT NULL DEFAULT '0',
  PAGINAS                  INT(11) NOT NULL DEFAULT '0',
  PESO                     INT(11) NOT NULL DEFAULT '0',
  OBJ_VALIDO               INT(11) NOT NULL DEFAULT '0',
  OBJ_INVALIDO             INT(11) NOT NULL DEFAULT '0',
  STATUS_ARQUIVO           INT(11) NOT NULL DEFAULT '0',
  MOVIMENTO                VARCHAR(8) NOT NULL,
  TIPO_DOCUMENTO           VARCHAR(10) NOT NULL,
  PRIMARY KEY  (ARQUIVO_ZIP, ARQUIVO_AFP,ARQUIVO_TXT)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;


CREATE TABLE IF NOT EXISTS proj_touchgraf_delphi__relatorio_diario.track_line (
  ARQUIVO_ZIP            VARCHAR(60) NOT NULL,
  ARQUIVO_AFP            VARCHAR(60) NOT NULL,
  ARQUIVO_TXT            VARCHAR(60) NOT NULL,
  SEQUENCIA_REGISTRO     INT(11) NOT NULL,
  TIMESTAMP              DATETIME NOT NULL,
  LOTE_PROCESSAMENTO     INT(11) NOT NULL,
  MOVIMENTO              VARCHAR(8) NOT NULL,
  ACABAMENTO             VARCHAR(20) NOT NULL,
  PAGINAS                INT(11) NOT NULL DEFAULT '0',
  FOLHAS                 INT(11) NOT NULL DEFAULT '0',
  ENCARTES               INT(11) NOT NULL DEFAULT '0',
  OF_ENVELOPE            VARCHAR(15) NOT NULL,
  OF_FORMULARIO          VARCHAR(15) NOT NULL,
  DATA_POSTAGEM          VARCHAR(10) NOT NULL,
  LOTE                   VARCHAR(5) NOT NULL,
  CARTAO                 VARCHAR(12) NOT NULL,
  CIF                    VARCHAR(34) NOT NULL,
  PESO                   VARCHAR(10) NOT NULL,
  DIRECAO                INT(11) NOT NULL,
  CATEGORIA              INT(11) NOT NULL,
  PORTE                  INT(11) NOT NULL,
  STATUS_REGISTRO        VARCHAR(20) NOT NULL,
  PAPEL                  VARCHAR(10) NOT NULL,
  TIPO_DOCUMENTO         VARCHAR(10) NOT NULL,
  LINHA                  TEXT,
  LINHA_REL              TEXT,
  PRIMARY KEY  (ARQUIVO_ZIP,ARQUIVO_AFP,ARQUIVO_TXT,SEQUENCIA_REGISTRO),
  KEY IDX_CHAVE2 (LOTE, DATA_POSTAGEM, TIPO_DOCUMENTO)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS proj_touchgraf_delphi__relatorio_diario.track_line_history (
  ARQUIVO_ZIP            VARCHAR(60) NOT NULL,
  ARQUIVO_AFP            VARCHAR(60) NOT NULL,
  ARQUIVO_TXT            VARCHAR(60) NOT NULL,
  SEQUENCIA_REGISTRO     INT(11) NOT NULL,
  TIMESTAMP              DATETIME NOT NULL,
  LOTE_PROCESSAMENTO     INT(11) NOT NULL,
  MOVIMENTO              VARCHAR(8) NOT NULL,
  ACABAMENTO             VARCHAR(20) NOT NULL,
  PAGINAS                INT(11) NOT NULL DEFAULT '0',
  FOLHAS                 INT(11) NOT NULL DEFAULT '0',
  ENCARTES               INT(11) NOT NULL DEFAULT '0',
  OF_ENVELOPE            VARCHAR(15) NOT NULL,
  OF_FORMULARIO          VARCHAR(15) NOT NULL,
  DATA_POSTAGEM          VARCHAR(10) NOT NULL,
  LOTE                   VARCHAR(5) NOT NULL,
  CARTAO                 VARCHAR(12) NOT NULL,
  CIF                    VARCHAR(34) NOT NULL,
  PESO                   VARCHAR(10) NOT NULL,
  DIRECAO                INT(11) NOT NULL,
  CATEGORIA              INT(11) NOT NULL,
  PORTE                  INT(11) NOT NULL,
  STATUS_REGISTRO        VARCHAR(20) NOT NULL,
  PAPEL                  VARCHAR(10) NOT NULL,
  TIPO_DOCUMENTO         VARCHAR(10) NOT NULL,
  LINHA                  TEXT,  
  LINHA_REL              TEXT,
  PRIMARY KEY  (ARQUIVO_ZIP,ARQUIVO_AFP,ARQUIVO_TXT,SEQUENCIA_REGISTRO),
  KEY IDX_CHAVE2 (LOTE, DATA_POSTAGEM, TIPO_DOCUMENTO)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;