USE [ClinicalGeniusSupplyChain]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[COLGetDianInvoiceLines]
    @InvoiceGuid NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        dil.InvoiceLineGuid,
        dil.InvoiceGuid,
        dil.LineNumber,
        dil.LineType,
        dil.ItemCode,
        dil.ItemDescription,
        dil.Quantity,
        dil.UnitOfMeasure,
        dil.UnitPrice,
        dil.LineGrossAmount,
        dil.LineDiscountAmount,
        dil.LineTaxableAmount,
        dil.LineTaxPercentage,
        dil.LineTaxAmount,
        dil.LineNetAmount
    FROM ClinicalGeniusSupplyChain.dbo.DianInvoiceLines dil WITH(NOLOCK)
    WHERE dil.InvoiceGuid = @InvoiceGuid
    ORDER BY dil.LineNumber ASC;
END;
GO