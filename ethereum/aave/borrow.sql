CREATE TABLE IF NOT EXISTS aave.borrow (   
    version text,
    transaction_type text,
    loan_type text,
    symbol text,
    token bytea,
    contract_address bytea,
    borrower bytea,
    repayer bytea,
    liquidator bytea,
    amount numeric,
    usd_amount numeric,
    evt_tx_hash bytea,
    evt_index integer,
    evt_block_time timestamptz,
    evt_block_number numeric,
    PRIMARY KEY (evt_tx_hash, evt_index)
);

CREATE OR REPLACE FUNCTION aave.insert_borrow(start_ts timestamptz, end_ts timestamptz=now(), start_block numeric=0, end_block numeric=9e18) RETURNS integer
LANGUAGE plpgsql AS $function$
DECLARE r integer;
BEGIN
WITH rows AS (
    INSERT INTO aave.borrow (
      version,
      transaction_type,
      loan_type,
      symbol,
      token,
      contract_address,
      borrower,
      repayer,
      liquidator,
      amount,
      usd_amount,
      evt_tx_hash,
      evt_index,
      evt_block_time,
      evt_block_number
    )
    ((SELECT

      version,
      transaction_type,
      loan_type,
      erc20.symbol,
      borrow.token,
      erc20.contract_address,
      borrower,
      repayer,
      liquidator,
      amount / (10^erc20.decimals) AS amount,
      (amount/(10^p.decimals)) * price AS usd_amount,
      evt_tx_hash,
      evt_index,
      evt_block_time,
      evt_block_number
    
FROM (
-- v1
-- borrow
SELECT 
    '1' AS version,
    'borrow' AS transaction_type,
    CASE 
        WHEN "_borrowRateMode" = '1' THEN 'stable'
        WHEN "_borrowRateMode" = '2' THEN 'variable'
    END AS loan_type,
    CASE
        WHEN _reserve = '\xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE' THEN '\xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2' --Use WETH instead of Aave "mock" address
        ELSE _reserve
    END AS token,
    "_user" AS borrower,
    NULL::bytea AS repayer,
    NULL::bytea AS liquidator,
    _amount AS amount, 
    evt_tx_hash,
    evt_index,
    evt_block_time,
    evt_block_number
FROM aave."LendingPool_evt_Borrow" 
WHERE evt_block_time >= start_ts
AND evt_block_time < end_ts
AND evt_block_number >= start_block
AND evt_block_number < end_block
UNION ALL 
-- all repays
SELECT 
    '1' AS version,
    'repay' AS transaction_type,
    NULL AS loan_type,
    CASE
        WHEN _reserve = '\xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE' THEN '\xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2' 
        ELSE _reserve
    END AS token,
    "_user" AS borrower,
    "_repayer" AS repayer,
    NULL::bytea AS liquidator,
    - "_amountMinusFees" AS amount,
    evt_tx_hash,
    evt_index,
    evt_block_time,
    evt_block_number
FROM aave."LendingPool_evt_Repay"
WHERE evt_block_time >= start_ts
AND evt_block_time < end_ts
AND evt_block_number >= start_block
AND evt_block_number < end_block
UNION ALL 
-- liquidation
SELECT 
    '1' AS version,
    'borrow_liquidation' AS transaction_type,
    NULL AS loan_type,
    CASE
        WHEN _reserve = '\xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE' THEN '\xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2' 
        ELSE _reserve
    END AS token,
    "_user" AS borrower,
    _liquidator AS repayer,
    _liquidator AS liquidator,
    - "_purchaseAmount" AS amount,
    evt_tx_hash,
    evt_index,
    evt_block_time,
    evt_block_number
FROM aave."LendingPool_evt_LiquidationCall"
WHERE evt_block_time >= start_ts
AND evt_block_time < end_ts
AND evt_block_number >= start_block
AND evt_block_number < end_block
UNION ALL 
SELECT 
    '2' AS version,
    'borrow' AS transaction_type,
    CASE 
        WHEN "borrowRateMode" = '1' THEN 'stable'
        WHEN "borrowRateMode" = '2' THEN 'variable'
    END AS loan_type,
    reserve AS token,
    "user" AS borrower, 
    NULL::bytea AS repayer,
    NULL::bytea AS liquidator,
    amount, 
    evt_tx_hash,
    evt_index,
    evt_block_time,
    evt_block_number
FROM aave_v2."LendingPool_evt_Borrow" 
WHERE evt_block_time >= start_ts
AND evt_block_time < end_ts
AND evt_block_number >= start_block
AND evt_block_number < end_block
UNION ALL 
-- all repays
SELECT 
    '2' AS version,
    'repay' AS transaction_type,
    NULL AS loan_type,
    reserve AS token,
    "user" AS borrower,
    repayer AS repayer,
    NULL::bytea AS liquidator,
    - amount AS amount,
    evt_tx_hash,
    evt_index,
    evt_block_time,
    evt_block_number
FROM aave_v2."LendingPool_evt_Repay"
WHERE evt_block_time >= start_ts
AND evt_block_time < end_ts
AND evt_block_number >= start_block
AND evt_block_number < end_block
UNION ALL 
-- liquidation
SELECT 
    '2' AS version,
    'borrow_liquidation' AS transaction_type,
    NULL AS loan_type,
    "debtAsset" AS token,
    "user" AS borrower,
    liquidator AS repayer,
    liquidator AS liquidator,
    - "debtToCover" AS amount,
    evt_tx_hash,
    evt_index,
    evt_block_time,
    evt_block_number
FROM aave_v2."LendingPool_evt_LiquidationCall"
WHERE evt_block_time >= start_ts
AND evt_block_time < end_ts
AND evt_block_number >= start_block
AND evt_block_number < end_block
) borrow
LEFT JOIN erc20."tokens" erc20
    ON borrow.token = erc20.contract_address
LEFT JOIN prices.usd p 
    ON p.minute = date_trunc('minute', borrow.evt_block_time) 
    AND p.contract_address = borrow.token
))
    ON CONFLICT DO NOTHING
    RETURNING 1
)
SELECT count(*) INTO r from rows;
RETURN r;
END
$function$;

SELECT aave.insert_borrow(DATE_TRUNC('day','2019-01-24'::timestamptz),DATE_TRUNC('day',NOW()) )
WHERE NOT EXISTS (
    SELECT *
    FROM aave.borrow
);

INSERT INTO cron.job (schedule, command)
VALUES ('*/20 * * * *', $$
    SELECT aave.insert_borrow(
        (SELECT MAX(evt_block_time) - interval '1 days' FROM aave.borrow),
        (SELECT now() - interval '20 minutes'),
        (SELECT MAX(number) FROM ethereum.blocks WHERE time < (SELECT MAX(evt_block_time) - interval '1 days' FROM aave.borrow)),
        (SELECT MAX(number) FROM ethereum.blocks where time < now() - interval '20 minutes'));
$$)
ON CONFLICT (command) DO UPDATE SET schedule=EXCLUDED.schedule;
