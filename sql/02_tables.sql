USE SnapAccess;
GO

-- raw: one column per file header, nothing typed, nothing trimmed

IF OBJECT_ID('raw.SnapRetailer') IS NULL
CREATE TABLE raw.SnapRetailer (
    [Record ID] NVARCHAR(255),
    [Store Name] NVARCHAR(255),
    [Store Type] NVARCHAR(255),
    [Street Number] NVARCHAR(255),
    [Street Name] NVARCHAR(255),
    [Additional Address] NVARCHAR(255),
    [City] NVARCHAR(255),
    [State] NVARCHAR(255),
    [Zip Code] NVARCHAR(255),
    [Zip4] NVARCHAR(255),
    [County] NVARCHAR(255),
    [Latitude] NVARCHAR(255),
    [Longitude] NVARCHAR(255),
    [Authorization Date] NVARCHAR(255),
    [End Date] NVARCHAR(255)
);

IF OBJECT_ID('raw.FoodAccessAtlas') IS NULL
CREATE TABLE raw.FoodAccessAtlas (
    [CensusTract] NVARCHAR(100),
    [State] NVARCHAR(100),
    [County] NVARCHAR(100),
    [Urban] NVARCHAR(100),
    [Pop2010] NVARCHAR(100),
    [OHU2010] NVARCHAR(100),
    [GroupQuartersFlag] NVARCHAR(100),
    [NUMGQTRS] NVARCHAR(100),
    [PCTGQTRS] NVARCHAR(100),
    [LILATracts_1And10] NVARCHAR(100),
    [LILATracts_halfAnd10] NVARCHAR(100),
    [LILATracts_1And20] NVARCHAR(100),
    [LILATracts_Vehicle] NVARCHAR(100),
    [HUNVFlag] NVARCHAR(100),
    [LowIncomeTracts] NVARCHAR(100),
    [PovertyRate] NVARCHAR(100),
    [MedianFamilyIncome] NVARCHAR(100),
    [LA1and10] NVARCHAR(100),
    [LAhalfand10] NVARCHAR(100),
    [LA1and20] NVARCHAR(100),
    [LATracts_half] NVARCHAR(100),
    [LATracts1] NVARCHAR(100),
    [LATracts10] NVARCHAR(100),
    [LATracts20] NVARCHAR(100),
    [LATractsVehicle_20] NVARCHAR(100),
    [LAPOP1_10] NVARCHAR(100),
    [LAPOP05_10] NVARCHAR(100),
    [LAPOP1_20] NVARCHAR(100),
    [LALOWI1_10] NVARCHAR(100),
    [LALOWI05_10] NVARCHAR(100),
    [LALOWI1_20] NVARCHAR(100),
    [lapophalf] NVARCHAR(100),
    [lapophalfshare] NVARCHAR(100),
    [lalowihalf] NVARCHAR(100),
    [lalowihalfshare] NVARCHAR(100),
    [lakidshalf] NVARCHAR(100),
    [lakidshalfshare] NVARCHAR(100),
    [laseniorshalf] NVARCHAR(100),
    [laseniorshalfshare] NVARCHAR(100),
    [lawhitehalf] NVARCHAR(100),
    [lawhitehalfshare] NVARCHAR(100),
    [lablackhalf] NVARCHAR(100),
    [lablackhalfshare] NVARCHAR(100),
    [laasianhalf] NVARCHAR(100),
    [laasianhalfshare] NVARCHAR(100),
    [lanhopihalf] NVARCHAR(100),
    [lanhopihalfshare] NVARCHAR(100),
    [laaianhalf] NVARCHAR(100),
    [laaianhalfshare] NVARCHAR(100),
    [laomultirhalf] NVARCHAR(100),
    [laomultirhalfshare] NVARCHAR(100),
    [lahisphalf] NVARCHAR(100),
    [lahisphalfshare] NVARCHAR(100),
    [lahunvhalf] NVARCHAR(100),
    [lahunvhalfshare] NVARCHAR(100),
    [lasnaphalf] NVARCHAR(100),
    [lasnaphalfshare] NVARCHAR(100),
    [lapop1] NVARCHAR(100),
    [lapop1share] NVARCHAR(100),
    [lalowi1] NVARCHAR(100),
    [lalowi1share] NVARCHAR(100),
    [lakids1] NVARCHAR(100),
    [lakids1share] NVARCHAR(100),
    [laseniors1] NVARCHAR(100),
    [laseniors1share] NVARCHAR(100),
    [lawhite1] NVARCHAR(100),
    [lawhite1share] NVARCHAR(100),
    [lablack1] NVARCHAR(100),
    [lablack1share] NVARCHAR(100),
    [laasian1] NVARCHAR(100),
    [laasian1share] NVARCHAR(100),
    [lanhopi1] NVARCHAR(100),
    [lanhopi1share] NVARCHAR(100),
    [laaian1] NVARCHAR(100),
    [laaian1share] NVARCHAR(100),
    [laomultir1] NVARCHAR(100),
    [laomultir1share] NVARCHAR(100),
    [lahisp1] NVARCHAR(100),
    [lahisp1share] NVARCHAR(100),
    [lahunv1] NVARCHAR(100),
    [lahunv1share] NVARCHAR(100),
    [lasnap1] NVARCHAR(100),
    [lasnap1share] NVARCHAR(100),
    [lapop10] NVARCHAR(100),
    [lapop10share] NVARCHAR(100),
    [lalowi10] NVARCHAR(100),
    [lalowi10share] NVARCHAR(100),
    [lakids10] NVARCHAR(100),
    [lakids10share] NVARCHAR(100),
    [laseniors10] NVARCHAR(100),
    [laseniors10share] NVARCHAR(100),
    [lawhite10] NVARCHAR(100),
    [lawhite10share] NVARCHAR(100),
    [lablack10] NVARCHAR(100),
    [lablack10share] NVARCHAR(100),
    [laasian10] NVARCHAR(100),
    [laasian10share] NVARCHAR(100),
    [lanhopi10] NVARCHAR(100),
    [lanhopi10share] NVARCHAR(100),
    [laaian10] NVARCHAR(100),
    [laaian10share] NVARCHAR(100),
    [laomultir10] NVARCHAR(100),
    [laomultir10share] NVARCHAR(100),
    [lahisp10] NVARCHAR(100),
    [lahisp10share] NVARCHAR(100),
    [lahunv10] NVARCHAR(100),
    [lahunv10share] NVARCHAR(100),
    [lasnap10] NVARCHAR(100),
    [lasnap10share] NVARCHAR(100),
    [lapop20] NVARCHAR(100),
    [lapop20share] NVARCHAR(100),
    [lalowi20] NVARCHAR(100),
    [lalowi20share] NVARCHAR(100),
    [lakids20] NVARCHAR(100),
    [lakids20share] NVARCHAR(100),
    [laseniors20] NVARCHAR(100),
    [laseniors20share] NVARCHAR(100),
    [lawhite20] NVARCHAR(100),
    [lawhite20share] NVARCHAR(100),
    [lablack20] NVARCHAR(100),
    [lablack20share] NVARCHAR(100),
    [laasian20] NVARCHAR(100),
    [laasian20share] NVARCHAR(100),
    [lanhopi20] NVARCHAR(100),
    [lanhopi20share] NVARCHAR(100),
    [laaian20] NVARCHAR(100),
    [laaian20share] NVARCHAR(100),
    [laomultir20] NVARCHAR(100),
    [laomultir20share] NVARCHAR(100),
    [lahisp20] NVARCHAR(100),
    [lahisp20share] NVARCHAR(100),
    [lahunv20] NVARCHAR(100),
    [lahunv20share] NVARCHAR(100),
    [lasnap20] NVARCHAR(100),
    [lasnap20share] NVARCHAR(100),
    [TractLOWI] NVARCHAR(100),
    [TractKids] NVARCHAR(100),
    [TractSeniors] NVARCHAR(100),
    [TractWhite] NVARCHAR(100),
    [TractBlack] NVARCHAR(100),
    [TractAsian] NVARCHAR(100),
    [TractNHOPI] NVARCHAR(100),
    [TractAIAN] NVARCHAR(100),
    [TractOMultir] NVARCHAR(100),
    [TractHispanic] NVARCHAR(100),
    [TractHUNV] NVARCHAR(100),
    [TractSNAP] NVARCHAR(100)
);
GO

-- lookups

IF OBJECT_ID('stg.StateRef') IS NULL
CREATE TABLE stg.StateRef (
    StateAbbr CHAR(2) NOT NULL PRIMARY KEY,
    StateName NVARCHAR(50) NOT NULL,
    MinLat DECIMAL(9,4) NOT NULL,
    MaxLat DECIMAL(9,4) NOT NULL,
    MinLon DECIMAL(9,4) NOT NULL,
    MaxLon DECIMAL(9,4) NOT NULL,
    Zip3From CHAR(3) NOT NULL,
    Zip3To CHAR(3) NOT NULL
);

-- this table is also the state filter for staging
IF NOT EXISTS (SELECT 1 FROM stg.StateRef)
INSERT INTO stg.StateRef VALUES
    ('OR', 'Oregon', 41.9, 46.3, -124.7, -116.4, '970', '979'),
    ('WA', 'Washington', 45.5, 49.1, -124.9, -116.9, '980', '994'),
    ('ID', 'Idaho', 41.9, 49.1, -117.3, -111.0, '832', '838'),
    ('NV', 'Nevada', 34.9, 42.1, -120.1, -114.0, '889', '898');

IF OBJECT_ID('stg.StreetSuffix') IS NULL
CREATE TABLE stg.StreetSuffix (
    Variant NVARCHAR(20) NOT NULL PRIMARY KEY,
    Standard NVARCHAR(10) NOT NULL
);

-- periods are stripped before lookup so ST. and AVE. land on ST and AVE
IF NOT EXISTS (SELECT 1 FROM stg.StreetSuffix)
INSERT INTO stg.StreetSuffix VALUES
    ('ST', 'ST'), ('STREET', 'ST'), ('STR', 'ST'),
    ('AVE', 'AVE'), ('AVENUE', 'AVE'), ('AV', 'AVE'),
    ('RD', 'RD'), ('ROAD', 'RD'),
    ('BLVD', 'BLVD'), ('BOULEVARD', 'BLVD'),
    ('DR', 'DR'), ('DRIVE', 'DR'),
    ('HWY', 'HWY'), ('HIGHWAY', 'HWY'),
    ('LN', 'LN'), ('LANE', 'LN'),
    ('CT', 'CT'), ('COURT', 'CT'),
    ('PL', 'PL'), ('PLACE', 'PL'),
    ('PKWY', 'PKWY'), ('PARKWAY', 'PKWY'),
    ('CIR', 'CIR'), ('CIRCLE', 'CIR'),
    ('TER', 'TER'), ('TERRACE', 'TER');
GO

-- staging

IF OBJECT_ID('stg.SnapRetailer') IS NULL
CREATE TABLE stg.SnapRetailer (
    RecordID INT NOT NULL,
    StoreName NVARCHAR(255) NOT NULL,
    StoreNameNorm NVARCHAR(255) NOT NULL,
    StoreType NVARCHAR(50) NOT NULL,
    StreetNumber NVARCHAR(50) NULL,
    StreetName NVARCHAR(255) NULL,
    AddressLine NVARCHAR(300) NULL,
    AdditionalAddress NVARCHAR(255) NULL,
    City NVARCHAR(100) NULL,
    StateAbbr CHAR(2) NOT NULL,
    Zip5 CHAR(5) NULL,
    Zip4 CHAR(4) NULL,
    County NVARCHAR(100) NULL,
    Latitude DECIMAL(9,6) NULL,
    Longitude DECIMAL(9,6) NULL,
    AuthorizationDate DATE NOT NULL,
    EndDate DATE NULL,
    RunID INT NOT NULL,
    CONSTRAINT PK_stg_SnapRetailer PRIMARY KEY (RecordID, AuthorizationDate)
);

IF OBJECT_ID('stg.FoodAccessTract') IS NULL
CREATE TABLE stg.FoodAccessTract (
    CensusTract CHAR(11) NOT NULL PRIMARY KEY,
    CountyFIPS CHAR(5) NOT NULL,
    StateAbbr CHAR(2) NOT NULL,
    StateName NVARCHAR(50) NOT NULL,
    CountyName NVARCHAR(100) NOT NULL,
    IsUrban BIT NULL,
    Pop2010 INT NOT NULL,
    IsLowIncome BIT NULL,
    IsLila1And10 BIT NULL,
    LowAccessPop1And10 DECIMAL(12,2) NULL,
    LowIncomeLowAccessPop1And10 DECIMAL(12,2) NULL,
    PovertyRate DECIMAL(6,2) NULL,
    MedianFamilyIncome INT NULL,
    SnapHouseholds INT NULL,
    RunID INT NOT NULL
);
GO

-- qa

IF OBJECT_ID('qa.Quarantine') IS NULL
CREATE TABLE qa.Quarantine (
    QuarantineID INT IDENTITY PRIMARY KEY,
    RunID INT NOT NULL,
    SourceTable NVARCHAR(100) NOT NULL,
    SourceKey NVARCHAR(100) NULL,
    Reason NVARCHAR(400) NOT NULL,
    RawValues NVARCHAR(MAX) NOT NULL,
    QuarantinedAt DATETIME2(0) NOT NULL DEFAULT SYSDATETIME()
);

IF OBJECT_ID('qa.DqResult') IS NULL
CREATE TABLE qa.DqResult (
    RunID INT NOT NULL,
    CheckName NVARCHAR(100) NOT NULL,
    FailCount INT NOT NULL,
    RowsChecked INT NOT NULL,
    SampleIDs NVARCHAR(400) NULL,
    CheckedAt DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT PK_qa_DqResult PRIMARY KEY (RunID, CheckName)
);

IF OBJECT_ID('qa.CountyReview') IS NULL
CREATE TABLE qa.CountyReview (
    RunID INT NOT NULL,
    Source NVARCHAR(20) NOT NULL,
    StateAbbr CHAR(2) NOT NULL,
    CountyName NVARCHAR(100) NOT NULL,
    Reason NVARCHAR(200) NOT NULL,
    Candidates NVARCHAR(400) NULL
);

IF OBJECT_ID('qa.ReconResult') IS NULL
CREATE TABLE qa.ReconResult (
    RunID INT NOT NULL,
    CheckName NVARCHAR(100) NOT NULL,
    Expected BIGINT NULL,
    Actual BIGINT NULL,
    Passed BIT NOT NULL,
    Detail NVARCHAR(400) NULL,
    CheckedAt DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT PK_qa_ReconResult PRIMARY KEY (RunID, CheckName)
);
GO

-- etl

IF OBJECT_ID('etl.RunIDSeq') IS NULL
CREATE SEQUENCE etl.RunIDSeq AS INT START WITH 1;

IF OBJECT_ID('etl.EtlRun') IS NULL
CREATE TABLE etl.EtlRun (
    EtlRunID INT IDENTITY PRIMARY KEY,
    RunID INT NOT NULL,
    Step NVARCHAR(100) NOT NULL,
    StartedAt DATETIME2(0) NOT NULL,
    EndedAt DATETIME2(0) NULL,
    RowsRead INT NULL,
    RowsLoaded INT NULL,
    RowsQuarantined INT NULL,
    RowsDeduped INT NULL,
    RowsFiltered INT NULL,
    Status NVARCHAR(20) NOT NULL,
    Message NVARCHAR(4000) NULL
);

IF OBJECT_ID('etl.CountyXref') IS NULL
CREATE TABLE etl.CountyXref (
    StateAbbr CHAR(2) NOT NULL,
    SnapCountyName NVARCHAR(100) NOT NULL,
    CountyKey INT NOT NULL,
    MatchMethod NVARCHAR(20) NOT NULL,
    RunID INT NOT NULL,
    CONSTRAINT PK_etl_CountyXref PRIMARY KEY (StateAbbr, SnapCountyName)
);
GO

-- dw

IF OBJECT_ID('dw.DimCounty') IS NULL
CREATE TABLE dw.DimCounty (
    CountyKey INT IDENTITY PRIMARY KEY,
    CountyFIPS CHAR(5) NOT NULL UNIQUE,
    StateAbbr CHAR(2) NOT NULL,
    StateName NVARCHAR(50) NOT NULL,
    CountyName NVARCHAR(100) NOT NULL,
    CountyNameNorm NVARCHAR(100) NOT NULL
);

IF NOT EXISTS (SELECT 1 FROM dw.DimCounty WHERE CountyKey = -1)
BEGIN
    SET IDENTITY_INSERT dw.DimCounty ON;
    INSERT INTO dw.DimCounty (CountyKey, CountyFIPS, StateAbbr, StateName, CountyName, CountyNameNorm)
    VALUES (-1, '00000', '--', 'Unknown', 'Unknown', 'UNKNOWN');
    SET IDENTITY_INSERT dw.DimCounty OFF;
END;

-- no FKs pointing here: the MERGE ... OUTPUT insert in usp_LoadDimRetailer doesn't allow them
IF OBJECT_ID('dw.DimRetailer') IS NULL
CREATE TABLE dw.DimRetailer (
    RetailerKey INT IDENTITY PRIMARY KEY,
    RecordID INT NOT NULL,
    StoreName NVARCHAR(255) NOT NULL,
    StoreType NVARCHAR(50) NOT NULL,
    AddressLine NVARCHAR(300) NULL,
    City NVARCHAR(100) NULL,
    StateAbbr CHAR(2) NOT NULL,
    Zip5 CHAR(5) NULL,
    RowHash VARBINARY(32) NOT NULL,
    ValidFrom DATETIME2(0) NOT NULL,
    ValidTo DATETIME2(0) NOT NULL,
    IsCurrent BIT NOT NULL
);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_DimRetailer_Current')
CREATE UNIQUE INDEX UX_DimRetailer_Current ON dw.DimRetailer (RecordID) WHERE IsCurrent = 1;

IF OBJECT_ID('dw.FactRetailerAuthorization') IS NULL
CREATE TABLE dw.FactRetailerAuthorization (
    RecordID INT NOT NULL,
    AuthorizationDate DATE NOT NULL,
    EndDate DATE NULL,
    RetailerKey INT NOT NULL,
    CountyKey INT NOT NULL,
    Latitude DECIMAL(9,6) NULL,
    Longitude DECIMAL(9,6) NULL,
    RunID INT NOT NULL,
    CONSTRAINT PK_dw_FactRetailerAuthorization PRIMARY KEY (RecordID, AuthorizationDate)
);

IF OBJECT_ID('dw.CountyFoodAccess') IS NULL
CREATE TABLE dw.CountyFoodAccess (
    CountyKey INT NOT NULL PRIMARY KEY,
    TractCount INT NOT NULL,
    Population2010 INT NOT NULL,
    LilaTractCount INT NOT NULL,
    LowIncomeLowAccessPop INT NOT NULL,
    LowIncomeLowAccessPct DECIMAL(5,2) NULL,
    SnapHouseholds INT NULL,
    RunID INT NOT NULL
);
GO
