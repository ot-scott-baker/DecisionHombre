USE [DecisionHombre] --<<-- database name
GO

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;SET XACT_ABORT ON;SET NOCOUNT ON;
SET IMPLICIT_TRANSACTIONS OFF; -- nant sets connection to implicit_transactions ON
GO

--DELETE version WHERE name = 'ECID' AND version = 2022.01

---set up  persistent version table-------
BEGIN TRANSACTION	IF OBJECT_ID('tempdb..#tversion') IS NOT NULL 	DROP TABLE #tversion CREATE TABLE #tversion ( [Version] DECIMAL(10,2), [Name] VARCHAR(50), IsError BIT, ErrMsg VARCHAR(1000), Comments VARCHAR(512) ) COMMIT TRANSACTION
------------add version and name to #tversion--------------
DECLARE	 @Name  VARCHAR(50)				= 'ECID'		--<<-- regular build, databasename  IF an OCR (not part of build) Request nnnnnn WHERE nnnnn = ticket number
		, @Version DECIMAL(10,2)		=  2175.01		--<<-- nnnnnn.dd  WHERE nnnnn = Ticketnumber and dd = equals sequence number (0 based) of how many scripts are created
		, @Comment VARCHAR(512)			= 'Create ZipCode to Est Income table and populate it'			--<<-- please put in a short comment that makes it easy to find IF the occasion arises
IF  NOT EXISTS (SELECT * FROM dbo.Version WHERE [Name] = @Name AND [Version] = @Version) --<<-- prevents re-running the script
BEGIN 	BEGIN TRANSACTION INSERT INTO #tversion ( [Version], [Name], IsError, Comments)	SELECT @Version, @Name, 0, @Comment	COMMIT TRANSACTION END
GO  
-->>-- IF procedure, then remove between GOs and put the procedure in -- alternate:  put a GO below the IF EXISTS to print a 'start' message
IF EXISTS (SELECT * FROM #tversion WHERE IsError = 0) -- if not empty and no error
BEGIN 

	BEGIN TRY

		DECLARE @dt DATETIME2 = SYSDATETIME() -- timer
			, @DynamicSQL NVARCHAR(1000)
		
		BEGIN TRANSACTION

		SET ANSI_NULLS ON
		
		SET QUOTED_IDENTIFIER ON
		
		SET ANSI_PADDING ON
		
		IF NOT EXISTS(SELECT * FROM sys.tables WHERE name = 'ZipIncomeEst' AND schema_id = SCHEMA_ID('Lkp'))
		CREATE TABLE Lkp.ZipIncomeEst(
			ZipCode INT NOT NULL CONSTRAINT [PK_ZipIncomeEst_ZipCode] PRIMARY KEY CLUSTERED,
			EstMedianAnnualIncome INT NOT NULL, 
			CreateDate DATETIME CONSTRAINT [DF_ZipIncomeEst_CreateDate] DEFAULT(GETDATE()),
			ModifyDate DATETIME CONSTRAINT [DF_ZipIncomeEst_ModifyDate] DEFAULT(GETDATE())
		) ON [PRIMARY]

		IF NOT EXISTS(SELECT * FROM sys.tables WHERE name = 'ZipIncomeEstHist' AND schema_id = SCHEMA_ID('Lkp'))
		CREATE TABLE Lkp.ZipIncomeEstHist(
			ZipIncomeEstHistID INT IDENTITY(1,1) CONSTRAINT [PK_ZipIncomeEstHist_ZipIncomeEstHistID] PRIMARY KEY CLUSTERED,
			ZipCode INT NOT NULL,
			EstMedianAnnualIncome INT NOT NULL, 
			CreateDate DATETIME NULL,
			ModifyDate DATETIME NULL,
			HstType CHAR(1) NOT NULL
		) ON [PRIMARY]					
		
		SET ANSI_PADDING OFF
		
		IF OBJECT_ID('tempdb..#TempTable') IS NOT NULL
		DROP TABLE #TempTable;
		
		CREATE TABLE #TempTable
		(
			ZipCode CHAR(5),
			EstMedianAnnualIncome INT
		);
		
		BULK INSERT #TempTable
		FROM 'C:\Imports\X20170712_00_vECID002175_00_cf.txt'
		WITH   (BATCHSIZE      = 5000 
				,DATAFILETYPE   = 'char'
				,FIRSTROW       = 1
				,FIELDTERMINATOR = '|'
				,ROWTERMINATOR = '\n'
				,MAXERRORS      = 5
		);
			
		PRINT 'BULK INSERT #TempTable ' + lower(@@rowcount) + ' rows.  Expected:  31994 rows.';
			
		INSERT Lkp.ZipIncomeEst (ZipCode, EstMedianAnnualIncome)
		SELECT ZipCode, EstMedianAnnualIncome
		FROM #TempTable p;
			
		PRINT '<<<INSERT Decision.ZipIncomeEst ' + lower(@@rowcount) + ' rows>>>';
			
		PRINT '>> ' + LOWER(CONVERT(DECIMAL(19,3),DATEDIFF(MILLISECOND, @dt, SYSDATETIME())/1000.000)) + ' seconds elapsed <<'
		PRINT '<< Request ECID-2175.01 complete >>' --<<-- where nnnnn = Ticket number
			
		COMMIT TRANSACTION
		
	END TRY
	BEGIN CATCH
	
		IF @@TRANCOUNT > 0
		BEGIN 
			ROLLBACK TRANSACTION
			PRINT 'Error caught.  Rolling back.'
		END
			
		UPDATE t
		SET IsError = 1, ErrMsg = ERROR_MESSAGE()
		FROM #tversion t
	
	END CATCH
	
	PRINT '-->>-- @@trancount = ' + LOWER(@@trancount)
	PRINT '-->>- XACT_STATE() = ' + LOWER(XACT_STATE())
	IF (@@trancount > 0) RAISERROR ( 'SCRIPT ERROR:  **@@trancount NOT ZERO** **UNCOMMITTED TRANSACTION IN SCRIPT**', 16, 1)

END
GO

DECLARE @name VARCHAR(50), @version DECIMAL(10,2), @iserror BIT, @errmsg VARCHAR(1000), @comment VARCHAR(512)
SELECT @name = [Name] 
		, @version = [Version]
		, @iserror = IsError
		, @errmsg = ErrMsg 
		, @comment = Comments
FROM #tversion
	
IF @iserror IS NULL  -- no op if #version is empty
RETURN
	
IF @iserror = 0
BEGIN
	PRINT 'Updating Version table with version ' + convert(varchar(12), @Version) + ' for ' + @Name	
	INSERT INTO Version ([Name], [Version], [Comments]) VALUES(@name, @version, @comment)	
END
ELSE 
BEGIN
	PRINT 'Version ' + convert(varchar(12), @Version) + ' for ' + @Name + ' FAILED. ' + @errmsg
	PRINT ' '
	RAISERROR ( @errmsg, 16, 10 ) -- force script failure to ensure nant stops processing
END
	
--------------- CLEAN UP -------------------------

IF OBJECT_ID('tempdb..#tversion') IS NOT NULL
DROP TABLE #tversion




