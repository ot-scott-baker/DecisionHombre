USE [DecisionHombre] --<<-- database name
GO
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;SET XACT_ABORT ON;SET NOCOUNT ON;
SET IMPLICIT_TRANSACTIONS OFF; -- nant sets connection to implicit_transactions ON
GO
---set up  persistent version table-------
BEGIN TRANSACTION	IF OBJECT_ID('tempdb..#tversion') IS NOT NULL 	DROP TABLE #tversion CREATE TABLE #tversion ( [Version] DECIMAL(10,2), [Name] VARCHAR(50), IsError BIT, ErrMsg VARCHAR(1000), Comments VARCHAR(512) ) COMMIT TRANSACTION
------------add version and name to #tversion--------------
DECLARE	 @Name  VARCHAR(50)				= 'ECID'		--<<-- regular build, databasename  IF an OCR (not part of build) Request nnnnnn WHERE nnnnn = ticket number
		, @Version DECIMAL(10,2)		=  2175.00		--<<-- nnnnnn.dd  WHERE nnnnn = Ticketnumber and dd = equals sequence number (0 based) of how many scripts are created
		, @Comment VARCHAR(512)			= 'Creating the Version table'			--<<-- please put in a short comment that makes it easy to find IF the occasion arises

-- Since we are creating the Version table we can't do the normal version stuff here.  HA

IF NOT EXISTS(SELECT * FROM sys.tables WHERE name = 'Version')
CREATE TABLE [dbo].[Version](
	[Id] [INT] IDENTITY(1,1) NOT NULL,
	[Version] [DECIMAL](7, 2) NULL,
	[Name] [VARCHAR](50) NOT NULL,
	[DateEntered] [DATETIME] NOT NULL,
	[CreateDate] [DATETIME] NULL,
	[ModifyDate] [DATETIME] NULL,
	[Comments] [VARCHAR](512) NULL,
 CONSTRAINT [PK_Version] PRIMARY KEY CLUSTERED 
(	[Id] DESC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

IF NOT EXISTS(SELECT * FROM sys.sysconstraints WHERE constid = OBJECT_ID('DF_Version_DateEntered') AND id = OBJECT_ID('Version'))
ALTER TABLE [dbo].[Version] ADD  CONSTRAINT [DF_Version_DateEntered]  DEFAULT (GETDATE()) FOR [DateEntered]

IF NOT EXISTS(SELECT * FROM sys.sysconstraints WHERE constid = OBJECT_ID('DF_Version_CreateDate') AND id = OBJECT_ID('Version'))
ALTER TABLE [dbo].[Version] ADD  CONSTRAINT [DF_Version_CreateDate]  DEFAULT (GETDATE()) FOR [CreateDate]

IF NOT EXISTS(SELECT * FROM sys.sysconstraints WHERE constid = OBJECT_ID('DF_Version_ModifyDate') AND id = OBJECT_ID('Version'))
ALTER TABLE [dbo].[Version] ADD  CONSTRAINT [DF_Version_ModifyDate]  DEFAULT (GETDATE()) FOR [ModifyDate]

IF NOT EXISTS(SELECT * FROM sys.sysconstraints WHERE constid = OBJECT_ID('DF_Version_Comments') AND id = OBJECT_ID('Version'))
ALTER TABLE [dbo].[Version] ADD  CONSTRAINT [DF_Version_Comments]  DEFAULT ('No comment') FOR [Comments]
GO

IF EXISTS(SELECT * FROM sys.triggers WHERE name = 'trg_version_modifyDate_Update')
DROP TRIGGER trg_Version_ModifyDate_Update
GO

CREATE TRIGGER [dbo].[trg_Version_ModifyDate_Update] ON [dbo].[Version]
AFTER UPDATE
AS
/************************************
Purpose:  update ModifyDate ON UPDATE
20100829
*************************************/
SET NOCOUNT ON
BEGIN TRY
	DECLARE @dt DATETIME
	SET @dt = getdate()
	IF NOT UPDATE(ModifyDate) 
	BEGIN
		UPDATE t
		SET ModifyDate = @dt
		FROM dbo.Version t
		INNER JOIN inserted i ON i.Id = t.Id
	END
END TRY
BEGIN CATCH
	DECLARE @errmsg VARCHAR(1000)
	SET @errmsg = 'Error in dbo.trg_Version_ModifyDate_Update :'  + Error_Message()
	RAISERROR ( @errmsg , 16, 10 )
END CATCH
GO

ALTER TABLE [dbo].[Version] ENABLE TRIGGER [trg_Version_ModifyDate_Update]
GO

PRINT '<< Request ECID-2175.00 complete >>' --<<-- where nnnnn = Ticket number
