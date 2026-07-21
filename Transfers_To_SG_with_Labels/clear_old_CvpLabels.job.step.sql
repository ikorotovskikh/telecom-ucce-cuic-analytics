DECLARE @Deleted_Rows INT;
DECLARE @Oldest_EventDT DATETIME;
SET @Deleted_Rows = 1;
SET @Oldest_EventDT = DATEADD(MONTH,-6,GETDATE())


WHILE (@Deleted_Rows > 0)
  BEGIN

   BEGIN TRANSACTION

   -- Delete some small number of rows at a time
     DELETE TOP (100000) FROM [STAT_DB].[dbo].[tCVP_Labels] 
     WHERE EventDT <=  @Oldest_EventDT

     SET @Deleted_Rows = @@ROWCOUNT;

   COMMIT TRANSACTION
   CHECKPOINT -- for simple recovery model
   
  END
