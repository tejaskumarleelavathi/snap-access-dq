USE SnapAccess;
GO

CREATE OR ALTER PROCEDURE etl.usp_RunPipeline
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @RunID INT = NEXT VALUE FOR etl.RunIDSeq, @started DATETIME2(0) = SYSDATETIME(), @err NVARCHAR(4000);

    INSERT INTO etl.EtlRun (RunID, Step, StartedAt, Status)
    VALUES (@RunID, 'pipeline', @started, 'Running');

    -- no wrapping transaction on purpose: if a step blows up the tables stay as they were
    -- at that point so the bad run can be poked at
    BEGIN TRY
        EXEC etl.usp_LoadRaw @RunID;
        EXEC etl.usp_LoadStaging @RunID;
        EXEC qa.usp_DataQualityChecks @RunID;
        EXEC etl.usp_MatchCounties @RunID;
        EXEC etl.usp_LoadDimRetailer @RunID;
        EXEC etl.usp_LoadFacts @RunID;
        EXEC qa.usp_Reconcile @RunID;

        UPDATE etl.EtlRun
        SET EndedAt = SYSDATETIME(), Status = 'Succeeded'
        WHERE RunID = @RunID AND Step = 'pipeline';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @err = CONCAT(ERROR_PROCEDURE(), ' line ', ERROR_LINE(), ': ', ERROR_MESSAGE());

        UPDATE etl.EtlRun
        SET EndedAt = SYSDATETIME(), Status = 'Failed', Message = @err
        WHERE RunID = @RunID AND Step = 'pipeline';

        THROW;
    END CATCH;
END;
GO
