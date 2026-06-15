@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Product Projection - Consumption View'
@Metadata.allowExtensions: true
@Search.searchable: true

define root view entity ZHB_C_PRODUCT
  provider contract transactional_query
  as projection on ZHB_I_PRODUCT
{
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
  key Product,
  
      @Search.defaultSearchElement: true
      ProductGroup,
      
      @Semantics.unitOfMeasure: true
      BaseUnit,
      
      ItemCategoryGroup,
      ProductHierarchy,
      Division,
      VarblPurOrdUnitIsActive,
      
      @Semantics.unitOfMeasure: true
      VolumeUnit,
      
      SalesStatus,
      TransportationGroup,
      SalesStatusValidityDate,
      AuthorizationGroup,
      ANPCode,
      ProductCategory,
      
      @Search.defaultSearchElement: true
      Brand,
      
      ProcurementRule,
      ValidityStartDate,
      LowLevelCode,
      ProdNoInGenProdInPrepackProd,
      SerialIdentifierAssgmtProfile,
      SizeOrDimensionText,
      IndustryStandardName,
      ProductStandardID,
      InternationalArticleNumberCat,
      ProductIsConfigurable,
      IsBatchManagementRequired,
      HasEmptiesBOM,
      ExternalProductGroup,
      CrossPlantConfigurableProduct,
      SerialNoExplicitnessLevel,
      ProductManufacturerNumber,
      ManufacturerNumber,
      ManufacturerPartProfile,
      QltyMgmtInProcmtIsActive,
      IsApprovedBatchRecordReqd,
      HandlingIndicator,
      WarehouseProductGroup,
      WarehouseStorageCondition,
      StandardHandlingUnitType,
      SerialNumberProfile,
      AdjustmentProfile,
      PreferredUnitOfMeasure,
      IsPilferable,
      IsRelevantForHzdsSubstances,
      TimeUnitForQuarantinePeriod,
      QualityInspectionGroup,
      HandlingUnitType,
      HasVariableTareWeight,
      OvercapacityTolerance,
      UnitForMaxPackagingDimensions,
      
      @Semantics.unitOfMeasure: true
      ProductMeasurementUnit,
      
      ProductValidStartDate,
      ArticleCategory,
      
      @Semantics.unitOfMeasure: true
      ContentUnit,
      
      ComparisonPriceQuantity,
      ProductValidEndDate,
      AssortmentListType,
      HasTextilePartsWthAnimalOrigin,
      ProductSeasonUsageCategory,
      IndustrySector,
      ChangeNumber,
      MaterialRevisionLevel,
      IsActiveEntity,
      
      @Semantics.systemDateTime.lastChangedAt: true
      LastChangeDateTime,
      
      LastChangeTime,
      DangerousGoodsIndProfile,
      ProductUUID,
      ProdSupChnMgmtUUID22,
      ProductDocumentChangeNumber,
      ProductDocumentPageCount,
      ProductDocumentPageNumber,
      OwnInventoryManagedProduct,
      DocumentIsCreatedByCAD,
      ProductionOrInspectionMemoTxt,
      ProductionMemoPageFormat,
      GlobalTradeItemNumberVariant,
      ProductIsHighlyViscous,
      TransportIsInBulk,
      ProdAllocDetnProcedure,
      ProdEffctyParamValsAreAssigned,
      ProdIsEnvironmentallyRelevant,
      LaboratoryOrDesignOffice,
      PackagingMaterialGroup,
      ProductIsLocked,
      DiscountInKindEligibility,
      SmartFormName,
      PackingReferenceProduct,
      BasicMaterial,
      ProductDocumentNumber,
      ProductDocumentVersion,
      ProductDocumentType,
      ProductDocumentPageFormat,
      ProductConfiguration,
      SegmentationStrategy,
      SegmentationIsRelevant,
      IsChemicalComplianceRelevant,
      ManufacturerBookPartNumber,
      LogisticalProductCategory,
      SalesProduct,
      ProdCharc1InternalNumber,
      ProdCharc2InternalNumber,
      ProdCharc3InternalNumber,
      ProductCharacteristic1,
      ProductCharacteristic2,
      ProductCharacteristic3,
      
      /* Associations */
      _ProductGroup,
      _ProductGroupText,
      _BaseUnitOfMeasure,
      _BaseUnitOfMeasureText,
      _ItemCategoryGroup,
      _ItemCategoryGroupText,
      _ProductHierarchy,
      _ProductHierarchyText,
      _MaterialText,
      _ProductCategory,
      _ProductCategoryText
}