-- Element NFT trades (re-usable macro for all chains)
{% macro element_v1_base_trades(blockchain, erc721_sell_order_filled, erc721_buy_order_filled, erc1155_sell_order_filled, erc1155_buy_order_filled) %}

{% if erc721_sell_order_filled != None %}
SELECT
  '{{blockchain}}' as blockchain,
  'element' as project,
  'v1' as project_version,
  evt_block_time AS block_time,
  cast(date_trunc('day', evt_block_time) as date) as block_date,
  cast(date_trunc('month', evt_block_time) as date) as block_month,
  evt_block_number AS block_number,
  'Buy' AS trade_category,
  'secondary' AS trade_type,
  erc721Token AS nft_contract_address,
  cast(erc721TokenId as uint256) AS nft_token_id,
  uint256 '1' AS nft_amount,
  taker AS buyer,
  maker AS seller,
  cast(erc20TokenAmount AS UINT256) AS price_raw,
  CASE
    WHEN erc20Token = 0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee AND '{{blockchain}}' = 'zksync' THEN 0x000000000000000000000000000000000000800a
    WHEN erc20Token = 0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee THEN 0x0000000000000000000000000000000000000000
    ELSE erc20Token
  END AS currency_contract,
  CAST(IF(CARDINALITY(fees) >= 1, JSON_EXTRACT_SCALAR(JSON_PARSE(fees[1]), '$.amount'), '0') AS UINT256) AS platform_fee_amount_raw,
  CAST(IF(CARDINALITY(fees) >= 2, JSON_EXTRACT_SCALAR(JSON_PARSE(fees[2]), '$.amount'), '0') AS UINT256) royalty_fee_amount_raw,
  from_hex(IF(CARDINALITY(fees) >= 1, JSON_EXTRACT_SCALAR(JSON_PARSE(fees[1]), '$.recipient'), NULL)) AS platform_fee_address,
  from_hex(IF(CARDINALITY(fees) >= 2, JSON_EXTRACT_SCALAR(JSON_PARSE(fees[2]), '$.recipient'), NULL)) AS royalty_fee_address,
  contract_address AS project_contract_address,
  evt_tx_hash AS tx_hash,
  evt_index AS sub_tx_trade_id
FROM {{ erc721_sell_order_filled }}
{% if is_incremental() %}
WHERE {{incremental_predicate('evt_block_time')}}
{% endif %}

UNION ALL

SELECT
  '{{blockchain}}' as blockchain,
  'element' as project,
  'v1' as project_version,
  evt_block_time AS block_time,
  cast(date_trunc('day', evt_block_time) as date) as block_date,
  cast(date_trunc('month', evt_block_time) as date) as block_month,
  evt_block_number AS block_number,
  'Sell' AS trade_category,
  'secondary' AS trade_type,
  erc721Token AS nft_contract_address,
  cast(erc721TokenId as uint256) AS nft_token_id,
  uint256 '1' AS nft_amount,
  maker AS buyer,
  taker AS seller,
  cast(erc20TokenAmount AS UINT256) AS price_raw,
  CASE
    WHEN erc20Token = 0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee AND '{{blockchain}}' = 'zksync' THEN 0x000000000000000000000000000000000000800a
    WHEN erc20Token = 0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee THEN 0x0000000000000000000000000000000000000000
    ELSE erc20Token
  END AS currency_contract,
  CAST(IF(CARDINALITY(fees) >= 1, JSON_EXTRACT_SCALAR(JSON_PARSE(fees[1]), '$.amount'), '0') AS UINT256) AS platform_fee_amount_raw,
  CAST(IF(CARDINALITY(fees) >= 2, JSON_EXTRACT_SCALAR(JSON_PARSE(fees[2]), '$.amount'), '0') AS UINT256) royalty_fee_amount_raw,
  from_hex(IF(CARDINALITY(fees) >= 1, JSON_EXTRACT_SCALAR(JSON_PARSE(fees[1]), '$.recipient'), NULL)) AS platform_fee_address,
  from_hex(IF(CARDINALITY(fees) >= 2, JSON_EXTRACT_SCALAR(JSON_PARSE(fees[2]), '$.recipient'), NULL)) AS royalty_fee_address,
  contract_address AS project_contract_address,
  evt_tx_hash AS tx_hash,
  evt_index AS sub_tx_trade_id
FROM {{ erc721_buy_order_filled }}
{% if is_incremental() %}
WHERE {{incremental_predicate('evt_block_time')}}
{% endif %}
{% endif %}

{% if erc721_sell_order_filled != None and erc1155_sell_order_filled != None %}
UNION ALL
{% endif %}

{% if erc1155_sell_order_filled != None %}
SELECT
  '{{blockchain}}' as blockchain,
  'element' as project,
  'v1' as project_version,
  evt_block_time AS block_time,
  cast(date_trunc('day', evt_block_time) as date) as block_date,
  cast(date_trunc('month', evt_block_time) as date) as block_month,
  evt_block_number AS block_number,
  'Buy' AS trade_category,
  'secondary' AS trade_type,
  erc1155Token AS nft_contract_address,
  cast(erc1155TokenId as uint256) AS nft_token_id,
  cast(erc1155FillAmount as uint256) AS nft_amount,
  taker AS buyer,
  maker AS seller,
  cast(erc20FillAmount AS UINT256) AS price_raw,
  CASE
    WHEN erc20Token = 0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee AND '{{blockchain}}' = 'zksync' THEN 0x000000000000000000000000000000000000800a
    WHEN erc20Token = 0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee THEN 0x0000000000000000000000000000000000000000
    ELSE erc20Token
  END AS currency_contract,
  CAST(IF(CARDINALITY(fees) >= 1, JSON_EXTRACT_SCALAR(JSON_PARSE(fees[1]), '$.amount'), '0') AS UINT256) AS platform_fee_amount_raw,
  CAST(IF(CARDINALITY(fees) >= 2, JSON_EXTRACT_SCALAR(JSON_PARSE(fees[2]), '$.amount'), '0') AS UINT256) royalty_fee_amount_raw,
  from_hex(IF(CARDINALITY(fees) >= 1, JSON_EXTRACT_SCALAR(JSON_PARSE(fees[1]), '$.recipient'), NULL)) AS platform_fee_address,
  from_hex(IF(CARDINALITY(fees) >= 2, JSON_EXTRACT_SCALAR(JSON_PARSE(fees[2]), '$.recipient'), NULL)) AS royalty_fee_address,
  contract_address AS project_contract_address,
  evt_tx_hash AS tx_hash,
  evt_index AS sub_tx_trade_id
FROM {{ erc1155_buy_order_filled }}
{% if is_incremental() %}
WHERE {{incremental_predicate('evt_block_time')}}
{% endif %}

UNION ALL

SELECT
  '{{blockchain}}' as blockchain,
  'element' as project,
  'v1' as project_version,
  evt_block_time AS block_time,
  cast(date_trunc('day', evt_block_time) as date) as block_date,
  cast(date_trunc('month', evt_block_time) as date) as block_month,
  evt_block_number AS block_number,
  'Buy' AS trade_category,
  'secondary' AS trade_type,
  erc1155Token AS nft_contract_address,
  cast(erc1155TokenId as uint256) AS nft_token_id,
  cast(erc1155FillAmount as uint256) AS nft_amount,
  maker AS buyer,
  taker AS seller,
  cast(erc20FillAmount AS UINT256) AS price_raw,
  CASE
    WHEN erc20Token = 0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee AND '{{blockchain}}' = 'zksync' THEN 0x000000000000000000000000000000000000800a
    WHEN erc20Token = 0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee THEN 0x0000000000000000000000000000000000000000
    ELSE erc20Token
  END AS currency_contract,
  CAST(IF(CARDINALITY(fees) >= 1, JSON_EXTRACT_SCALAR(JSON_PARSE(fees[1]), '$.amount'), '0') AS UINT256) AS platform_fee_amount_raw,
  CAST(IF(CARDINALITY(fees) >= 2, JSON_EXTRACT_SCALAR(JSON_PARSE(fees[2]), '$.amount'), '0') AS UINT256) royalty_fee_amount_raw,
  from_hex(IF(CARDINALITY(fees) >= 1, JSON_EXTRACT_SCALAR(JSON_PARSE(fees[1]), '$.recipient'), NULL)) AS platform_fee_address,
  from_hex(IF(CARDINALITY(fees) >= 2, JSON_EXTRACT_SCALAR(JSON_PARSE(fees[2]), '$.recipient'), NULL)) AS royalty_fee_address,
  contract_address AS project_contract_address,
  evt_tx_hash AS tx_hash,
  evt_index AS sub_tx_trade_id
FROM {{ erc1155_sell_order_filled }}
{% if is_incremental() %}
WHERE {{incremental_predicate('evt_block_time')}}
{% endif %}
{% endif %}

{% endmacro %}
