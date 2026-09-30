USE wls_db;
SHOW TABLES;

DESCRIBE items;

INSERT INTO vendors (vendor_name)
VALUES
('Vendor A'),
('Vendor B');

INSERT INTO brands (brand_name)
VALUES
('Brand A'),
('Brand B');

INSERT INTO functional_categories
(category_name)
VALUES
('Seafood');

INSERT INTO functional_items
(category_id, functional_name)
VALUES
(1, 'Sushi Tuna');

INSERT INTO units_of_measure
(unit_code, unit_name, unit_type)
VALUES
('PC', 'Piece', 'count'),
('CS', 'Case', 'package'),
('LB', 'Pound', 'weight');


INSERT INTO items (
    functional_item_id,
    brand_id,
    sku,
    item_name,
    purchase_unit_id,
    sales_unit_id,
    inventory_unit_id,
    is_variable_weight,
    break_case_allowed,
    default_moq,
    temperature,
    stack_limit,
    pallet_layer_quantity,
    moq_weight
)
VALUES (
    1,
    1,
    'TUNA-A-20',
    'Brand A Sushi Tuna 20lb',
    2,
    3,
    3,
    TRUE,
    TRUE,
    1,
    'cold',
    3,
    20,
    20
);


INSERT INTO item_unit_conversions (
    item_id,
    from_unit_id,
    to_unit_id,
    conversion_factor,
    is_default
)
VALUES (
    1,
    2,
    3,
    20,
    TRUE
);

# test item unit conversion
SELECT
	i.item_name,
    u1.unit_name AS from_unit,
    u2.unit_name AS to_unit,
    c.conversion_factor
FROM item_unit_conversions c
JOIN items i ON c.item_id = i.item_id
JOIN units_of_measure u1 ON c.from_unit_id = u1.unit_id
JOIN units_of_measure u2 ON c.to_unit_id = u2.unit_id;

# test calcualtion
SELECT 3 * conversion_factor AS pounds
FROM item_unit_conversions
WHERE item_id = 1
	AND from_unit_id = 2
    AND to_unit_id = 3;


INSERT INTO item_vendors (
    item_id,
    vendor_id,
    vendor_sku,
    is_primary_vendor,
    moq
)
VALUES
(1, 1, 'VA-TUNA', TRUE, 5),
(1, 2, 'VB-TUNA', FALSE, 2);


#test multiple vendors
SELECT
    i.item_name,
    v.vendor_name,
    iv.vendor_sku,
    iv.moq
FROM item_vendors iv
JOIN items i
    ON iv.item_id = i.item_id
JOIN vendors v
    ON iv.vendor_id = v.vendor_id;
    
