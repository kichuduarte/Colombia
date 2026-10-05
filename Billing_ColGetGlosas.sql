USE [ClinicalGeniusSupplyChain]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[COLGetGlosas]
    @FacilityId NVARCHAR(50),
    @GlosaGuid NVARCHAR(50) = NULL,
    @InvoiceNumber NVARCHAR(20) = NULL,
    @Status VARCHAR(30) = NULL,
    @StartDate DATE = NULL,
    @EndDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        g.GlosaGuid,
        g.InvoiceGuid,
        g.FacilityId,
        
        -- Invoice Context
        inv.InvoiceNumber,
        inv.IssueDateTime AS InvoiceDate,
        
        -- Patient Context (Crucial for UI Visibility)
        inv.PatientId,
        pat.PatientFullName,
        
        -- Payer Context
        inv.PayerId,
        pay.PayerName,
        
        -- Glosa Action Metrics
        g.PayerGlosaReference,
        g.RadicationDate,
        g.ResponseDeadlineDate,
        DATEDIFF(DAY, CAST(GETDATE() AS DATE), g.ResponseDeadlineDate) AS DaysRemaining,
        g.TotalDisputedAmount,
        g.TotalAcceptedAmount,
        g.TotalDefendedAmount,
        g.Status,
        g.CreationSource, 
        g.DateTimeEntered,
        g.LastUpdatedBy,
        
        -- Original UBL 2.1 Invoice Financials
        inv.GrossAmount AS InvoiceGrossAmount,
        inv.DiscountAmount AS InvoiceDiscountAmount,
        inv.TaxableAmount AS InvoiceTaxableAmount,
        inv.TaxAmount AS InvoiceTaxAmount,
        inv.CopayOrCuotaAmount AS InvoiceCopayAmount,
        inv.NetAmount AS InvoiceTotalAmount
        
    FROM ClinicalGeniusSupplyChain.dbo.InvoiceGlosas g WITH(NOLOCK)
    INNER JOIN ClinicalGeniusSupplyChain.dbo.DianInvoices inv WITH(NOLOCK) 
        ON inv.InvoiceGuid = g.InvoiceGuid
    -- Optimized join: Connects directly using the cached PayerId to avoid cross-database hops
    LEFT JOIN ClinicalGeniusSupplyChain.dbo.Payers pay WITH(NOLOCK) 
        ON pay.NationalId = inv.PayerId
    -- Extract clean Patient Full Name
    OUTER APPLY (
        SELECT LTRIM(RTRIM(
            REPLACE(
                ISNULL(p.PatientFirstName, '') + ' ' + 
                ISNULL(p.PatientMiddleName + ' ', '') + 
                ISNULL(p.PatientLastName, ''), 
                '  ', ' '
            )
        )) AS PatientFullName
        FROM ClinicalGeniusEhr.dbo.PatientTable p WITH(NOLOCK)
        WHERE p.RecordUniqueId = inv.PatientId
    ) pat
    WHERE g.FacilityId = @FacilityId
      AND (@Status IS NULL OR g.Status = @Status)
      AND (@GlosaGuid IS NULL OR g.GlosaGuid = @GlosaGuid)
      AND (@InvoiceNumber IS NULL OR inv.InvoiceNumber = @InvoiceNumber)
      AND (@StartDate IS NULL OR g.RadicationDate >= @StartDate)
      AND (@EndDate IS NULL OR g.RadicationDate <= @EndDate)
    ORDER BY g.ResponseDeadlineDate ASC;
END;
GO