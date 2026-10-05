-- ==========================================================================================
-- DIAN HEADER ROLLUP INITIALIZATION ENGINE 
-- TARGET ARCHITECTURE: SQL Server Enterprise 2014 
-- PURPOSE: Aggregates line-item UBL 2.1 totals to the header after batch insertion
-- ==========================================================================================
USE [ClinicalGeniusSupplyChain]
GO

/****** Object:  COLInsertDIANTotals ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[COLInsertDIANTotals]
    @InvoiceGuid NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @InvoiceGuid = LTRIM(RTRIM(@InvoiceGuid));

    BEGIN TRAN;
    BEGIN TRY
        
        -- 1. Declare Rollup Variables
        DECLARE @TotalGross DECIMAL(18,2) = 0.00,
                @TotalDiscount DECIMAL(18,2) = 0.00,
                @TotalTaxable DECIMAL(18,2) = 0.00,
                @TotalTax DECIMAL(18,2) = 0.00,
                @TotalNet DECIMAL(18,2) = 0.00;

        -- 2. Aggregate from Itemized Lines
        SELECT 
            @TotalGross = ISNULL(SUM(LineGrossAmount), 0.00),
            @TotalDiscount = ISNULL(SUM(LineDiscountAmount), 0.00),
            @TotalTaxable = ISNULL(SUM(LineTaxableAmount), 0.00),
            @TotalTax = ISNULL(SUM(LineTaxAmount), 0.00),
            @TotalNet = ISNULL(SUM(LineNetAmount), 0.00)
        FROM ClinicalGeniusSupplyChain.dbo.DianInvoiceLines WITH(NOLOCK)
        WHERE InvoiceGuid = @InvoiceGuid;

        -- 3. Cement the Header Totals
        UPDATE ClinicalGeniusSupplyChain.dbo.DianInvoices
        SET 
            GrossAmount = @TotalGross,
            DiscountAmount = @TotalDiscount,
            TaxableAmount = @TotalTaxable,
            TaxAmount = @TotalTax,
            NetAmount = @TotalNet,
            -- Ensure the mathematical validation ties perfectly
            CopayOrCuotaAmount = 0.00 
        WHERE InvoiceGuid = @InvoiceGuid;

        COMMIT TRAN;

        -- Return the InvoiceGuid back to the UI in case of further chaining
        SELECT @InvoiceGuid AS InvoiceGuid;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;

        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE(),
                @ErrorSeverity INT = ERROR_SEVERITY(),
                @ErrorState INT = ERROR_STATE();
                
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END;
GO