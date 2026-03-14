USE SnapAccess;
GO

-- trim, upper, collapse runs of spaces. char(7) trick avoids a loop.
-- a few store names have non-breaking spaces that TRIM won't touch
CREATE OR ALTER FUNCTION etl.fn_CleanText (@s NVARCHAR(4000))
RETURNS NVARCHAR(4000)
WITH SCHEMABINDING
AS
BEGIN
    SET @s = REPLACE(@s, NCHAR(160), N' ');
    RETURN NULLIF(UPPER(TRIM(
        REPLACE(REPLACE(REPLACE(@s, N' ', N' ' + NCHAR(7)), NCHAR(7) + N' ', N''), NCHAR(7), N'')
    )), N'');
END;
GO

-- accents are handled at compare time with an _AI collation, not here
CREATE OR ALTER FUNCTION etl.fn_NormCountyName (@name NVARCHAR(200))
RETURNS NVARCHAR(200)
AS
BEGIN
    DECLARE @s NVARCHAR(200) = N' ' + TRANSLATE(UPPER(@name), N'.,''-', N'    ') + N' ';

    SET @s = REPLACE(@s, N' SAINT ', N' ST ');
    SET @s = REPLACE(@s, N' STE ', N' ST ');
    SET @s = etl.fn_CleanText(@s);

    IF @s LIKE N'% COUNTY'
        SET @s = LEFT(@s, LEN(@s) - 7);

    RETURN @s;
END;
GO
