CREATE DATABASE IF NOT EXISTS wls_db;
USE wls_db;

# every unique billing vendor
CREATE TABLE vendors (
    vendor_id INT AUTO_INCREMENT PRIMARY KEY,
    vendor_name VARCHAR(255) NOT NULL,
    address VARCHAR(500),
    phone VARCHAR(255),
    email VARCHAR(255),
    website VARCHAR(255),
    notes TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);


#item may differ in quality, origins, packaging
CREATE TABLE brands (
    brand_id INT AUTO_INCREMENT PRIMARY KEY,
    brand_name VARCHAR(255) NOT NULL UNIQUE,
    notes TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);


# self joining hierarchical category
CREATE TABLE functional_categories (
	category_id INT AUTO_INCREMENT PRIMARY KEY,
    parent_category_id INT NULL,
    category_name VARCHAR(255) NOT NULL,
    
	FOREIGN KEY (parent_category_id)
		REFERENCES functional_categories(category_id)
		ON DELETE SET NULL
);

# multiple sku/brands -> functional item
CREATE TABLE functional_items (
	functional_item_id INT AUTO_INCREMENT PRIMARY KEY,
	category_id INT NULL,
    functional_name VARCHAR(255) NOT NULL,
    description TEXT,
    
    FOREIGN KEY (category_id) 
		REFERENCES functional_categories(category_id)
		ON DELETE SET NULL
);

# for better searching
CREATE TABLE functional_item_aliases (
	alias_id INT AUTO_INCREMENT PRIMARY KEY,
    functional_item_id INT NOT NULL, 
    alias_name VARCHAR(255) NOT NULL,
    language_code VARCHAR(10),
    is_primary BOOLEAN DEFAULT FALSE,
    
    FOREIGN KEY (functional_item_id)
		REFERENCES functional_items(functional_item_id)
		ON DELETE CASCADE, 
        
	UNIQUE (functional_item_id, alias_name, language_code)
);

CREATE TABLE units_of_measure (
	unit_id INT AUTO_INCREMENT PRIMARY KEY,
    unit_code VARCHAR(30) NOT NULL UNIQUE,
    unit_name VARCHAR(100) NOT NULL,
    unit_type ENUM(
		'count',
        'weight',
        'volume',
        'package'
    ) NOT NULL,
    
    description VARCHAR(255)
);	

# item sku
# functional item = sushi tuna : yellowfin tuna
# physical item = 
# 					brand A sushi yellowfin tuna 30 lb case
#					brand B sushi yellowfin tuna 20 lb case

CREATE TABLE items (
	item_id INT AUTO_INCREMENT PRIMARY KEY,
    
    functional_item_id INT NULL,
    brand_id INT NULL,
    
    sku VARCHAR(255) UNIQUE, 
    item_name VARCHAR(255) NOT NULL,
    description TEXT,
    
    purchase_unit_id INT, # typical purchase unit
    sales_unit_id INT, # most common sold unit
    inventory_unit_id INT,
    is_variable_weight BOOLEAN DEFAULT FALSE,
    break_case_allowed BOOLEAN DEFAULT FALSE,
    
    default_moq DECIMAL(12,3),
    
    temperature ENUM (
		'cold',
        'dry',
        'fresh'
    ), # used for storage
    stack_limit INT, # number of item stackable with itself before packaging breaking, 0 = nonstackable, highest number has to fit in standard box truck
    pallet_layer_quantity INT, # number of item than can fit flat on a pallet layer, same orientation as max stackable limit
								# both should be based on sales unit
    moq_weight DECIMAL(12,3),
    
    active BOOLEAN DEFAULT TRUE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (brand_id)
        REFERENCES brands(brand_id)
        ON DELETE SET NULL,
    FOREIGN KEY (purchase_unit_id)
        REFERENCES units_of_measure(unit_id)
        ON DELETE SET NULL,
    FOREIGN KEY (sales_unit_id)
        REFERENCES units_of_measure(unit_id)
        ON DELETE SET NULL,
    FOREIGN KEY (inventory_unit_id)
        REFERENCES units_of_measure(unit_id)
        ON DELETE SET NULL
);


# larger to smaller = #smaller/1xlarge unit
# variable weight should not need a fixed conversion
CREATE TABLE item_unit_conversions (
	item_unit_id INT AUTO_INCREMENT PRIMARY KEY,
    item_id INT NOT NULL,
    from_unit_id INT NOT NULL,
	to_unit_id INT NOT NULL,
    
    conversion_factor DECIMAL(18,6) NOT NULL,
    is_default BOOLEAN DEFAULT FALSE,
    
    notes VARCHAR(255),
    
    FOREIGN KEY (item_id)
		REFERENCES items(item_id)
        ON DELETE CASCADE,
        
	FOREIGN KEY (from_unit_id)
		REFERENCES units_of_measure(unit_id)
        ON DELETE RESTRICT,
        
	FOREIGN KEY (to_unit_id)
		REFERENCES units_of_measure(unit_id)
        ON DELETE RESTRICT,
    
    UNIQUE(item_id, from_unit_id, to_unit_id)

);

# one item from mulitiple vendors
CREATE TABLE item_vendors (
	item_vendor_id INT AUTO_INCREMENT PRIMARY KEY,
    item_id INT NOT NULL,
    vendor_id INT NOT NULL,
    vendor_sku VARCHAR(100),
    is_primary_vendor BOOLEAN DEFAULT FALSE,
    moq DECIMAL(12,3),
    active BOOLEAN DEFAULT TRUE,
    notes TEXT,
    
    FOREIGN KEY (item_id)
		REFERENCES items(item_id)
        ON DELETE CASCADE,
	
	FOREIGN KEY (vendor_id)
		REFERENCES vendors(vendor_id)
        ON DELETE CASCADE,
	UNIQUE (item_id, vendor_id) 
);

# item costs per vendor
CREATE TABLE item_vendor_cost_history (
    item_vendor_cost_id INT AUTO_INCREMENT PRIMARY KEY,

    item_vendor_id INT NOT NULL,

    unit_cost DECIMAL(12,4) NOT NULL,

    effective_from DATE NOT NULL,
    effective_to DATE NULL,

    price_source VARCHAR(100),
    notes TEXT,

    FOREIGN KEY (item_vendor_id)
        REFERENCES item_vendors(item_vendor_id)
        ON DELETE CASCADE
);

# one sku multiple batches
# one batch one vendor one price
CREATE TABLE item_batches (
	batch_id INT AUTO_INCREMENT PRIMARY KEY,
    item_id INT NOT NULL,
    vendor_id INT NULL,
    batch_number VARCHAR(100),
    received_date DATE NOT NULL,
    expiration_date DATE NULL,

    initial_quantity DECIMAL(12,3) NOT NULL,
    current_quantity DECIMAL(12,3),
    purchase_unit_id INT NULL,
    purchase_unit_cost DECIMAL(12,4),
    unit_weight DECIMAL(12,4),
    notes TEXT,

    FOREIGN KEY (item_id)
        REFERENCES items(item_id)
        ON DELETE RESTRICT,
    FOREIGN KEY (vendor_id)
        REFERENCES vendors(vendor_id)
        ON DELETE SET NULL,
    FOREIGN KEY (purchase_unit_id)
        REFERENCES units_of_measure(unit_id)
        ON DELETE SET NULL
);


CREATE TABLE vendor_bills (
    vendor_bill_id INT AUTO_INCREMENT PRIMARY KEY,
    vendor_id INT NOT NULL,
    bill_number VARCHAR(100) NOT NULL,
    bill_date DATE NOT NULL,
    due_date DATE,
    status ENUM(
        'open',
        'partial',
        'paid',
        'void',
        'overdue'
    ) DEFAULT 'open',

    subtotal DECIMAL(14,2) DEFAULT 0,
    tax DECIMAL(14,2) DEFAULT 0,
    shipping DECIMAL(14,2) DEFAULT 0,
    total DECIMAL(14,2) DEFAULT 0,
    notes TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (vendor_id)
        REFERENCES vendors(vendor_id)
        ON DELETE RESTRICT,
    UNIQUE (vendor_id,bill_number)
);

# billing each item batch
CREATE TABLE vendor_bill_items (
    vendor_bill_item_id INT AUTO_INCREMENT PRIMARY KEY,
    vendor_bill_id INT NOT NULL,
    item_id INT NOT NULL,
    batch_id INT NULL,

    description VARCHAR(500),
    quantity DECIMAL(12,3) NOT NULL,
    unit_id INT,
    unit_cost DECIMAL(12,4) NOT NULL,
    amount DECIMAL(14,2),
    
    FOREIGN KEY (vendor_bill_id)
        REFERENCES vendor_bills(vendor_bill_id)
        ON DELETE CASCADE,
    FOREIGN KEY (item_id)
        REFERENCES items(item_id)
        ON DELETE RESTRICT,
    FOREIGN KEY (batch_id)
        REFERENCES item_batches(batch_id)
        ON DELETE SET NULL,
    FOREIGN KEY (unit_id)
        REFERENCES units_of_measure(unit_id)
        ON DELETE SET NULL
);

#
CREATE TABLE customers (
    customer_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_name VARCHAR(255) NOT NULL,

    contact_name VARCHAR(255),
    phone VARCHAR(50),
    email VARCHAR(255),

    address VARCHAR(500),
    city VARCHAR(100),
    state VARCHAR(100),
    postal_code VARCHAR(20),

    latitude DECIMAL(10,7),
    longitude DECIMAL(10,7),

    payment_terms_days INT DEFAULT 0,
    active BOOLEAN DEFAULT TRUE,
    notes TEXT,

    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

# if have key, no limitation on delivery dates
# each customer have multiple deliverable time intervals
CREATE TABLE delivery_day_hours(
	delivery_hours_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    have_key BOOLEAN DEFAULT FALSE,
    day_of_week ENUM('Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'),
    open_time TIME, 
    close_time TIME,
	
    FOREIGN KEY (customer_id)
		REFERENCES customers(customer_id)
        ON DELETE CASCADE
);


# customer have multiple pricing over same item 
CREATE TABLE customer_item_prices(
	cusomter_item_price_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    item_id INT NOT NULL,
    price DECIMAL(12,4) NOT NULL,
    price_level ENUM('Default','Competitive', 'Comfortable', 'Matching') DEFAULT 'Default',
    
    effctive_from DATE NOT NULL,
    effctive_to DATE NULL,
    price_source VARCHAR(255), # implment fk ref sales representative
    adjustment_reason VARCHAR(255), # addtional justifications
    notes TEXT,
    
    FOREIGN KEY (customer_id)
		REFERENCES customers(customer_id)
        ON DELETE CASCADE,
	FOREIGN KEY (item_id)
		REFERENCES items(item_id)
        ON DELETE CASCADE
);

CREATE TABLE invoices (
	invoice_id INT AUTO_INCREMENT PRIMARY KEY,
    invoice_number VARCHAR(100) NOT NULL UNIQUE,
    customer_id INT NOT NULL,
    invoice_date DATE NOT NULL,
    due_date DATE,
    
    status ENUM('open', 'paid', 'partial', 'void', 'overdue','pending'),
    
    #subtotal DECIMAL(14,2) DEFAULT 0,
    #tax DECIMAL(14,2) DEFAULT 0,
    total DECIMAL(14,2) DEFAULT 0,
    
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (customer_id)
		REFERENCES customers(customer_id)
        ON DELETE RESTRICT
);


# basic invoicing unit
CREATE TABLE invoice_items (
	invoice_item_id INT AUTO_INCREMENT PRIMARY KEY,
    invoice_id INT NOT NULL,
    item_id INT NOT NULL,
    
    batch_id INT NULL, # take from oldest batch
    description VARCHAR(500),
    
    quantity DECIMAL(12,3) NOT NULL,
    unit_id INT,
    unit_price DECIMAL(12,4) NOT NULL, #input by sales, can be reconmended via default prices
    actual_weight DECIMAL(12,4),
    amount DECIMAL(12,2),
    
    memo TEXT,
    
    FOREIGN KEY (item_id)
		REFERENCES items(item_id)
        ON DELETE RESTRICT,
    FOREIGN KEY (invoice_id)
		REFERENCES invoices(invoice_id)
        ON DELETE CASCADE,
	FOREIGN KEY (batch_id)
		REFERENCES item_batches(batch_id)
        ON DELETE SET NULL,
	FOREIGN KEY (unit_id)
		REFERENCES units_of_measure(unit_id)
        ON DELETE SET NULL
);


# manage invetory
CREATE TABLE inventory_transactions (
	inventory_transaction_id INT AUTO_INCREMENT PRIMARY KEY,
    item_id INT NOT NULL,
    batch_id INT NULL,
    
    transaction_type ENUM(
		'recieve',
        'sale',
        'return',
        'adjustment',
        'transfer',
        'waste'
        ) NOT NULL,
	quantity DECIMAL(12,3) NOT NULL,
    unit_id INT,
    transaction_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    reference_type VARCHAR(50),
    reference_id BIGINT,
    notes TEXT,
    
    FOREIGN KEY (item_id)
		REFERENCES items(item_id)
        ON DELETE RESTRICT,
	FOREIGN KEY (batch_id)
		REFERENCES item_batches(batch_id)
        ON DELETE SET NULL,
	FOREIGN KEY (unit_id)
		REFERENCES units_of_measure(unit_id)
        ON DELETE SET NULL

);

# item substitutions
CREATE TABLE item_substitutions (
    substitution_id INT AUTO_INCREMENT PRIMARY KEY,
    item_id INT NOT NULL,
    substitute_item_id INT NOT NULL,
    substitution_priority INT DEFAULT 1,
    notes TEXT,

    FOREIGN KEY (item_id)
        REFERENCES items(item_id)
        ON DELETE CASCADE,
    FOREIGN KEY (substitute_item_id)
        REFERENCES items(item_id)
        ON DELETE CASCADE,
    UNIQUE (
        item_id,
        substitute_item_id
    )
);



# cash, checking, recivable, cost of goods...
CREATE TABLE financial_accounts (
    account_id INT AUTO_INCREMENT PRIMARY KEY,
    account_name VARCHAR(255) NOT NULL,
    account_type ENUM(
        'asset',
        'liability',
        'equity',
        'revenue',
        'expense'
    ) NOT NULL,
    account_number VARCHAR(100),
    active BOOLEAN DEFAULT TRUE,
    notes TEXT
);

# in practice, statements should only be generated when being paid, therefore immediately paid
# if partial, it should be paid by each invoice
CREATE TABLE statements (
    statement_id INT AUTO_INCREMENT PRIMARY KEY,

    statement_number VARCHAR(100) UNIQUE,

    statement_date DATE NOT NULL,
    due_date DATE,

    total_amount DECIMAL(14,2) DEFAULT 0,

    status ENUM(
        'open',
        'partial',
        'paid',
        'void'
    ) DEFAULT 'open',

    notes TEXT
);

# many statements to many invoices
CREATE TABLE statement_invoices (
    statement_id INT NOT NULL,
    invoice_id INT NOT NULL,
    PRIMARY KEY (statement_id,invoice_id),
    FOREIGN KEY (statement_id)
        REFERENCES statements(statement_id)
        ON DELETE CASCADE,
    FOREIGN KEY (invoice_id)
        REFERENCES invoices(invoice_id)
        ON DELETE CASCADE
);

CREATE TABLE payments (
    payment_id INT AUTO_INCREMENT PRIMARY KEY,
    account_id INT NOT NULL,
    payment_date DATE NOT NULL,
    amount DECIMAL(14,2) NOT NULL,
    payment_method ENUM(
        'cash',
        'check',
        'credit_card',
        'bank_transfer', #ZELLE
        'other'
    ) NOT NULL,
    reference_number VARCHAR(100),
    notes TEXT,
    FOREIGN KEY (account_id)
        REFERENCES financial_accounts(account_id)
        ON DELETE RESTRICT
);

# many invoice to one payment
CREATE TABLE payment_invoice_allocations (
    payment_id INT NOT NULL,
    invoice_id INT NOT NULL,
    amount_allocated DECIMAL(14,2) NOT NULL,

    PRIMARY KEY (payment_id,invoice_id),
    FOREIGN KEY (payment_id)
        REFERENCES payments(payment_id)
        ON DELETE CASCADE,
    FOREIGN KEY (invoice_id)
        REFERENCES invoices(invoice_id)
        ON DELETE CASCADE
);

# not needed
CREATE TABLE payment_statement_allocations (
    payment_id INT NOT NULL,
    statement_id INT NOT NULL,
    amount_allocated DECIMAL(14,2) NOT NULL,

    PRIMARY KEY (payment_id,statement_id),
    FOREIGN KEY (payment_id)
        REFERENCES payments(payment_id)
        ON DELETE CASCADE,
    FOREIGN KEY (statement_id)
        REFERENCES statements(statement_id)
        ON DELETE CASCADE
);

# add enum & types 
CREATE TABLE expenses (
    expense_id INT AUTO_INCREMENT PRIMARY KEY,
    account_id INT NOT NULL,
    expense_date DATE NOT NULL,
    amount DECIMAL(14,2) NOT NULL,
    description VARCHAR(500),
    vendor_id INT NULL,
    reference_number VARCHAR(100),
    notes TEXT,

    FOREIGN KEY (account_id)
        REFERENCES financial_accounts(account_id)
        ON DELETE RESTRICT,
    FOREIGN KEY (vendor_id)
        REFERENCES vendors(vendor_id)
        ON DELETE SET NULL
);
