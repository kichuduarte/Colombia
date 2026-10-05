USE [ClinicalGeniusSupplyChain]
GO

-- ==========================================================================================
-- 1. CATALOG: OFFICIAL MINSALUD GLOSA CODES (Res. 2284 de 2023 / Res. 1885 de 2024)
-- ==========================================================================================
CREATE TABLE ClinicalGeniusSupplyChain.dbo.Catalog_GlosaCodes (
    GeneralCode VARCHAR(2) NOT NULL,            -- e.g., 'FA' (Facturación), 'TA' (Tarifas)
    SpecificCode VARCHAR(4) NOT NULL,           -- Expanded to 4 to support e.g., '0103', '1605'
    Description NVARCHAR(255) NOT NULL,         -- Official MinSalud description
    Active BIT NOT NULL DEFAULT 1,
    CONSTRAINT PK_CatalogGlosaCodes PRIMARY KEY CLUSTERED (GeneralCode, SpecificCode)
);

-- ==========================================================================================
-- 2. HEADER: GLOSA DISPUTE TRACKER
-- ==========================================================================================
CREATE TABLE ClinicalGeniusSupplyChain.dbo.InvoiceGlosas (
    FacilityId NVARCHAR(50) NOT NULL,
    GlosaGuid NVARCHAR(50) NOT NULL DEFAULT CAST(NEWID() AS NVARCHAR(50)),
    InvoiceGuid NVARCHAR(50) NOT NULL,          -- FK to DianInvoices
    PayerGlosaReference NVARCHAR(100) NOT NULL, -- The tracking number provided by the EPS
    
    RadicationDate DATE NOT NULL,               -- Date the glosa was officially received
    ResponseDeadlineDate DATE NOT NULL,         -- RadicationDate + 15 business days
    
    TotalDisputedAmount DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    TotalAcceptedAmount DECIMAL(18,2) NOT NULL DEFAULT 0.00,  -- Amount IPS concedes
    TotalDefendedAmount DECIMAL(18,2) NOT NULL DEFAULT 0.00,  -- Amount IPS legally justifies
    
    Status VARCHAR(30) NOT NULL DEFAULT 'Radicada', 
    CreationSource VARCHAR(30) NOT NULL DEFAULT 'Manual',     -- 'Manual' or 'Electronic'
    
    DateTimeEntered DATETIME NOT NULL DEFAULT GETDATE(),
    LastUpdatedBy NVARCHAR(100) NOT NULL,
    DateTimeLastUpdated DATETIME NULL,
    CONSTRAINT PK_InvoiceGlosas PRIMARY KEY CLUSTERED (GlosaGuid)
);

-- ==========================================================================================
-- 3. DETAIL: LINE-LEVEL FINANCIAL MAPPING
-- ==========================================================================================
CREATE TABLE ClinicalGeniusSupplyChain.dbo.InvoiceGlosaLines (
    GlosaLineGuid NVARCHAR(50) NOT NULL DEFAULT CAST(NEWID() AS NVARCHAR(50)),
    GlosaGuid NVARCHAR(50) NOT NULL,            -- FK to InvoiceGlosas
    InvoiceLineGuid NVARCHAR(50) NOT NULL,      -- FK to DianInvoiceLines
    
    LineNumber INT NOT NULL,                    -- Stores the sequential 1, 2, 3... Glosa line order
    
    GeneralGlosaCode VARCHAR(2) NOT NULL,       -- Matches Catalog_GlosaCodes.GeneralCode
    SpecificGlosaCode VARCHAR(4) NOT NULL,      -- Expanded to 4 to match Catalog_GlosaCodes.SpecificCode
    
    DisputedAmount DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    AcceptedAmount DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    DefendedAmount DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    
    PayerObservation NVARCHAR(MAX) NULL,        -- EPS medical auditor's justification
    IpsAuditResponse NVARCHAR(MAX) NULL,        -- Your medical auditor's defense
    LineStatus VARCHAR(30) NOT NULL DEFAULT 'Pending', 
    
    CONSTRAINT PK_InvoiceGlosaLines PRIMARY KEY CLUSTERED (GlosaLineGuid)
);

-- ==========================================================================================
-- 4. WORKFLOW: AUDIT RESPONSE & LIFECYCLE TRACKING
-- ==========================================================================================
CREATE TABLE ClinicalGeniusSupplyChain.dbo.InvoiceGlosaResponses (
    ResponseGuid NVARCHAR(50) NOT NULL DEFAULT CAST(NEWID() AS NVARCHAR(50)),
    GlosaGuid NVARCHAR(50) NOT NULL,            -- FK to InvoiceGlosas
    
    ActionType VARCHAR(50) NOT NULL,            -- 'Respuesta_IPS', 'Ratificacion_EPS', etc.
    OficioNumber NVARCHAR(100) NULL,            -- Formal document tracking number
    ActionDate DATE NOT NULL,
    
    AttachedEvidenceUrl NVARCHAR(1000) NULL,    -- Azure blob storage link for clinical notes/RIPS
    AdjustmentInvoiceGuid NVARCHAR(50) NULL,    -- FK to DianInvoices if Nota Crédito was generated
    
    AuditNotes NVARCHAR(MAX) NULL,
    CreatedBy NVARCHAR(100) NOT NULL,
    DateTimeEntered DATETIME NOT NULL DEFAULT GETDATE(),
    
    CONSTRAINT PK_InvoiceGlosaResponses PRIMARY KEY CLUSTERED (ResponseGuid)
);

-- ==========================================================================================
-- PERFORMANCE INDICES
-- ==========================================================================================
CREATE NONCLUSTERED INDEX IX_InvoiceGlosas_InvoiceGuid ON ClinicalGeniusSupplyChain.dbo.InvoiceGlosas (InvoiceGuid);
CREATE NONCLUSTERED INDEX IX_InvoiceGlosas_Deadline ON ClinicalGeniusSupplyChain.dbo.InvoiceGlosas (ResponseDeadlineDate) INCLUDE (Status);
CREATE NONCLUSTERED INDEX IX_InvoiceGlosaLines_GlosaGuid ON ClinicalGeniusSupplyChain.dbo.InvoiceGlosaLines (GlosaGuid);
GO