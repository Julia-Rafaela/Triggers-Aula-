USE master
CREATE DATABASE ex_triggers_07
GO
USE ex_triggers_07
GO
CREATE TABLE cliente (
codigo INT NOT NULL,
nome VARCHAR(70) NOT NULL
PRIMARY KEY(codigo)
)
GO
CREATE TABLE produto (
codigo_produto INT NOT NULL,
nome_produto VARCHAR(100) NOT NULL,
preco DECIMAL(7,2) NOT NULL,
PRIMARY KEY (codigo_produto)
)
 
GO
CREATE TABLE venda (
codigo_venda INT NOT NULL,
codigo_cliente INT NOT NULL,
codigo_produto INT NOT NULL,
valor_total DECIMAL(7,2) NOT NULL
PRIMARY KEY (codigo_venda)
FOREIGN KEY (codigo_cliente) REFERENCES cliente(codigo),
FOREIGN KEY (codigo_produto) REFERENCES produto(codigo_produto)
)
GO
CREATE TABLE pontos (
codigo_cliente INT NOT NULL,
total_pontos DECIMAL(4,1) NOT NULL
PRIMARY KEY (codigo_cliente)
FOREIGN KEY (codigo_cliente) REFERENCES cliente(codigo)
)
 
INSERT INTO cliente (codigo, nome) VALUES 
(1, 'João'),
(2, 'Maria'),
(3, 'Pedro'),
(4, 'Ana'),
(5, 'Camila')
INSERT INTO cliente (codigo, nome) VALUES 
(6, 'Laura')
 
 
INSERT INTO produto (codigo_produto, nome_produto, preco) VALUES 
(1, 'Camiseta', 25.99),
(2, 'Calça Jeans', 39.99),
(3, 'Tênis', 59.99)
 
  
--- Para não prejudicar a tabela venda, nenhum produto pode ser deletado, mesmo que não
--venha mais a ser vendido
 
CREATE TRIGGER t_delproduto ON produto
FOR DELETE
AS
BEGIN
	ROLLBACK TRANSACTION
	RAISERROR('Não é possível excluir produto', 16, 1)
END
 
DELETE produto
WHERE codigo_produto = 1

INSERT INTO venda (codigo_venda, codigo_cliente, codigo_produto, valor_total) VALUES 
(101, 1, 1, 25.99),
(102, 2, 2, 39.99),
(103, 3, 3, 59.99)
 
 
-- Para não prejudicar os relatórios e a contabilidade, a tabela venda não pode ser alterada.
-- Ao invés de alterar a tabela venda deve-se exibir uma tabela com o nome do último cliente que
--comprou e o valor da última compra
CREATE TRIGGER t_updtvenda ON venda
INSTEAD OF UPDATE
AS
BEGIN
	SELECT TOP 1  c.nome AS nome_cliente, v.valor_total AS ultima_compra
   FROM cliente c
   INNER JOIN venda v ON c.codigo = v.codigo_cliente
   ORDER BY v.codigo_venda DESC
END

UPDATE venda
SET valor_total = 50.99
WHERE codigo_venda = 103
 
-- Após a inserção de cada linha na tabela venda, 10% do total deverá ser transformado em pontos.
CREATE TRIGGER t_calculate_points
ON venda
AFTER INSERT
AS
BEGIN
    DECLARE @codigo_cliente INT, @valor_total DECIMAL(7,2), @pontos DECIMAL(4,1);
 
    SELECT @codigo_cliente = inserted.codigo_cliente, @valor_total = inserted.valor_total
    FROM inserted
 
    SET @pontos = @valor_total * 0.1
 
    INSERT INTO pontos (codigo_cliente, total_pontos)
    VALUES (@codigo_cliente, @pontos)
END
 
INSERT INTO venda (codigo_venda, codigo_cliente, codigo_produto, valor_total) VALUES 
(104, 3, 1, 89.99)
 
SELECT * FROM cliente
SELECT * FROM pontos
 
 
-- Se o cliente ainda não estiver na tabela de pontos, deve ser inserido automaticamente após
--sua primeira compra
-- Se o cliente atingir 1 ponto, deve receber uma mensagem (PRINT SQL Server) dizendo que
--ganhou e remove esse 1 ponto da tabela de pontos
CREATE TRIGGER t_insert_venda ON venda
AFTER INSERT
AS
BEGIN
    IF EXISTS (SELECT * FROM inserted)
    BEGIN
        INSERT INTO pontos (codigo_cliente, total_pontos)
        SELECT i.codigo_cliente, 0
        FROM inserted i
        WHERE NOT EXISTS (
            SELECT 1 FROM pontos p WHERE p.codigo_cliente = i.codigo_cliente
        );
        DECLARE @cliente_ganhou_ponto INT;
        SELECT @cliente_ganhou_ponto = codigo_cliente
        FROM pontos
        WHERE codigo_cliente IN (SELECT codigo_cliente FROM inserted)
          AND total_pontos >= 1;
 
        IF (@cliente_ganhou_ponto IS NOT NULL)
        BEGIN
            PRINT 'Cliente ' + CAST(@cliente_ganhou_ponto AS VARCHAR(10)) + ' ganhou 1 ponto!';
            UPDATE pontos
            SET total_pontos = total_pontos - 1
            WHERE codigo_cliente = @cliente_ganhou_ponto;
        END
    END
END
 
INSERT INTO venda (codigo_venda, codigo_cliente, codigo_produto, valor_total) VALUES 
(107, 6, 2, 25.99)
 
SELECT * FROM pontos
 
--Fazer uma TRIGGER AFTER na tabela Venda que, uma vez feito um INSERT, verifique se a quan�dade
--está disponível em estoque. Caso esteja, a venda se concretiza, caso contrário, a venda deverá ser
--cancelada e uma mensagem de erro deverá ser enviada. A mesma TRIGGER deverá validar, caso a
--venda se concretize, se o estoque está abaixo do estoque mínimo determinado ou se após a venda,
--ficará abaixo do estoque considerado mínimo e deverá lançar um print na tela avisando das duas situações.
--Fazer uma UDF (User Defined Function) Multi Statement Table, que apresente, para uma dada nota
--fiscal, a seguinte saída:
--(Nota_Fiscal | Codigo_Produto | Nome_Produto | Descricao_Produto | Valor_Unitario | Quantidade | Valor_Total*)
-- Considere que Valor_Total = Valor_Unitário * Quantidade
GO
CREATE TABLE produto2 (
codigo INT NOT NULL,
nome VARCHAR(100) NOT NULL,
descricao VARCHAR(100) NOT NULL,
valor_unitario DECIMAL(7,2) NOT NULL,
PRIMARY KEY (codigo)
)
 
GO
CREATE TABLE estoque (
codigo_produto INT NOT NULL,
qtd_estoque    INT NOT NULL,
estoque_minimo INT NOT NULL,
PRIMARY KEY (codigo_produto),
FOREIGN KEY (codigo_produto) REFERENCES produto2 (codigo)
)
GO
CREATE TABLE venda2 (
nota_fiscal INT NOT NULL,
codigo_produto INT NOT NULL,
quantidade  INT NOT NULL
PRIMARY KEY (nota_fiscal)
FOREIGN KEY (codigo_produto) REFERENCES produto(codigo_produto)
)
 
 
CREATE TRIGGER tr_verificar_estoque
ON venda2
AFTER INSERT
AS
BEGIN
    DECLARE @codigo_produto INT, @quantidade INT, @estoque_disponivel INT, @estoque_minimo INT;
 
    SELECT @codigo_produto = codigo_produto, @quantidade = quantidade
    FROM inserted;
 
    SELECT @estoque_disponivel = qtd_estoque, @estoque_minimo = estoque_minimo
    FROM estoque
    WHERE codigo_produto = @codigo_produto;
 
    IF (@quantidade > @estoque_disponivel)
    BEGIN
        RAISERROR ('Erro: Quantidade insuficiente em estoque para o produto.', 16, 1);
        ROLLBACK TRANSACTION;
    END
    ELSE
    BEGIN
        IF (@estoque_disponivel <= @estoque_minimo)
        BEGIN
            PRINT 'Aviso: Estoque do produto (' + CAST(@codigo_produto AS VARCHAR(10)) + ') está abaixo do estoque mínimo.';
        END
    END
END
 
CREATE FUNCTION udf_detalhes_nota_fiscal (@nota_fiscal INT)
RETURNS TABLE
AS
RETURN (
    SELECT v.nota_fiscal, v.codigo_produto, p.nome AS nome_produto, p.descricao AS descricao_produto, p.valor_unitario,
           v.quantidade, p.valor_unitario * v.quantidade AS valor_total
    FROM venda2 v
    INNER JOIN produto2 p ON v.codigo_produto = p.codigo
    WHERE v.nota_fiscal = @nota_fiscal
)
 
INSERT INTO produto2 (codigo, nome, descricao, valor_unitario)
VALUES 
(1, 'Produto A', 'Descrição do Produto A', 10.99),
(2, 'Produto B', 'Descrição do Produto B', 20.99)

INSERT INTO estoque (codigo_produto, qtd_estoque, estoque_minimo)
VALUES
(1, 100, 20), 
(2, 50, 10)

INSERT INTO venda2 (nota_fiscal, codigo_produto, quantidade)
VALUES (1001, 1, 15)

INSERT INTO venda2 (nota_fiscal, codigo_produto, quantidade)
VALUES (1002, 2, 60)-- Nota fiscal 1002, compra do Produto B com 60 unidades (mais do que o estoque disponível)

SELECT * FROM udf_detalhes_nota_fiscal(1001)