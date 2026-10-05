USE [ClinicalGeniusSupplyChain]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[COLGetGlosaLines]
    @GlosaGuid NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        gl.GlosaLineGuid,
        gl.InvoiceLineGuid,
        gl.LineNumber AS GlosaLineNumber, 
        dil.LineNumber AS DianLineNumber, 
        dil.ItemCode AS CupsCode,
        dil.ItemDescription,
        dil.Quantity,
        dil.UnitOfMeasure,
        dil.UnitPrice,
        
        -- Full UBL 2.1 Original Line Financials for Audit Context
        dil.LineGrossAmount,
        dil.LineDiscountAmount,
        dil.LineTaxableAmount,
        dil.LineTaxPercentage,
        dil.LineTaxAmount,
        dil.LineNetAmount AS OriginalLineAmount,
        
        -- Glosa Dispute Metrics
        gl.GeneralGlosaCode,
        gl.SpecificGlosaCode,
        c.Description AS GlosaCodeDescription,
        ISNULL(gl.DisputedAmount, 0.00) AS DisputedAmount,
        ISNULL(gl.AcceptedAmount, 0.00) AS AcceptedAmount,
        ISNULL(gl.DefendedAmount, 0.00) AS DefendedAmount,
        gl.PayerObservation,
        gl.IpsAuditResponse,
        gl.LineStatus
    FROM ClinicalGeniusSupplyChain.dbo.InvoiceGlosaLines gl WITH(NOLOCK)
    INNER JOIN ClinicalGeniusSupplyChain.dbo.DianInvoiceLines dil WITH(NOLOCK) 
        ON dil.InvoiceLineGuid = gl.InvoiceLineGuid
    LEFT JOIN ClinicalGeniusSupplyChain.dbo.Catalog_GlosaCodes c WITH(NOLOCK) 
        ON c.GeneralCode = gl.GeneralGlosaCode AND c.SpecificCode = gl.SpecificGlosaCode
    WHERE gl.GlosaGuid = @GlosaGuid
    ORDER BY gl.LineNumber ASC; 
END;
GO