USE [ClinicalGeniusSupplyChain]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[COLUpdateGlosa]
    @GlosaGuid              NVARCHAR(50),
    @TargetStatus           VARCHAR(30) = NULL,
    @ActionType             VARCHAR(50) = NULL,
    @PayerGlosaReference    NVARCHAR(100) = NULL,
    @UserId                 NVARCHAR(100) = 'System'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @TotalDisputed DECIMAL(18,2) = 0.00;
    DECLARE @TotalAccepted DECIMAL(18,2) = 0.00;
    DECLARE @TotalDefended DECIMAL(18,2) = 0.00;
    DECLARE @CreationSource VARCHAR(30);

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Identify the CreationSource to determine if line resequencing is required
        SELECT @CreationSource = CreationSource 
        FROM ClinicalGeniusSupplyChain.dbo.InvoiceGlosas WITH(NOLOCK) 
        WHERE GlosaGuid = @GlosaGuid;

        -- 2. Resequence LineNumbers for Manual Glosas based on their inherited order
        IF @CreationSource = 'Manual'
        BEGIN
            ;WITH ResequencedLines AS (
                SELECT 
                    LineNumber,
                    ROW_NUMBER() OVER (ORDER BY LineNumber ASC, GlosaLineGuid ASC) AS SequentialLineNumber
                FROM ClinicalGeniusSupplyChain.dbo.InvoiceGlosaLines
                WHERE GlosaGuid = @GlosaGuid
            )
            UPDATE ResequencedLines
            SET LineNumber = SequentialLineNumber;
        END

        -- 3. Recalculate financial totals directly from the audited lines to ensure data integrity
        SELECT 
            @TotalDisputed = ISNULL(SUM(DisputedAmount), 0.00),
            @TotalAccepted = ISNULL(SUM(AcceptedAmount), 0.00),
            @TotalDefended = ISNULL(SUM(DefendedAmount), 0.00)
        FROM ClinicalGeniusSupplyChain.dbo.InvoiceGlosaLines WITH(NOLOCK)
        WHERE GlosaGuid = @GlosaGuid;

        -- 4. Update the Header Record
        -- Uses ISNULL to allow partial updates (e.g., updating just the reference vs. changing the workflow status)
        UPDATE ClinicalGeniusSupplyChain.dbo.InvoiceGlosas
        SET 
            Status = ISNULL(@TargetStatus, Status),
            PayerGlosaReference = ISNULL(@PayerGlosaReference, PayerGlosaReference),
            TotalDisputedAmount = @TotalDisputed,
            TotalAcceptedAmount = @TotalAccepted,
            TotalDefendedAmount = @TotalDefended,
            LastUpdatedBy = @UserId,
            DateTimeLastUpdated = GETDATE()
        WHERE GlosaGuid = @GlosaGuid;

        -- 5. Workflow Lifecycle: Insert the Audit Response Tracking Record
        -- This is triggered by the 'ActionType=Respuesta_IPS' parameter from the UI button
        IF @ActionType IS NOT NULL
        BEGIN
            INSERT INTO ClinicalGeniusSupplyChain.dbo.InvoiceGlosaResponses (
                ResponseGuid,
                GlosaGuid,
                ActionType,
                ActionDate,
                CreatedBy,
                DateTimeEntered
            )
            VALUES (
                CAST(NEWID() AS NVARCHAR(50)),
                @GlosaGuid,
                @ActionType,
                CAST(GETDATE() AS DATE),
                @UserId,
                GETDATE()
            );
        END

        COMMIT TRANSACTION;

        -- 6. Return all Glosa header fields back to the UI framework
        SELECT 
            FacilityId,
            GlosaGuid,
            InvoiceGuid,
            PayerGlosaReference,
            RadicationDate,
            ResponseDeadlineDate,
            TotalDisputedAmount,
            TotalAcceptedAmount,
            TotalDefendedAmount,
            Status,
            CreationSource,
            DateTimeEntered,
            LastUpdatedBy,
            DateTimeLastUpdated
        FROM ClinicalGeniusSupplyChain.dbo.InvoiceGlosas WITH(NOLOCK)
        WHERE GlosaGuid = @GlosaGuid;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE(),
                @ErrSeverity INT = ERROR_SEVERITY(),
                @ErrState INT = ERROR_STATE();

        RAISERROR(@ErrMsg, @ErrSeverity, @ErrState);
    END CATCH;
END;
GO