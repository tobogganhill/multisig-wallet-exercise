pragma solidity ^0.5.0;


contract MultiSignatureWallet {
    struct Transaction {
        bool executed;
        address destination;
        uint256 value;
        bytes data;
    }

    event Submission(uint256 indexed transactionId);
    event Deposit(address indexed sender, uint256 value);
    event Confirmation(address indexed sender, uint256 indexed transactionId);
    event Execution(uint256 indexed transactionId);
    event ExecutionFailure(uint256 indexed transactionId);

    address[] public owners;
    uint256 public required;
    mapping(address => bool) public isOwner;

    uint256 public transactionCount;
    mapping(uint256 => Transaction) public transactions;

    mapping(uint256 => mapping(address => bool)) public confirmations;

    modifier validRequirement(uint256 ownerCount, uint256 _required) {
        if (_required > ownerCount || _required == 0 || ownerCount == 0)
            revert();
        _;
    }

    /// @dev Fallback function allows to deposit ether.
    function() external payable {
        if (msg.value > 0) {
            emit Deposit(msg.sender, msg.value);
        }
    }

    // Public functions

    /// @dev Contract constructor sets initial owners and required number of confirmations.
    /// @param _owners List of initial owners.
    /// @param _required Number of required confirmations.

    constructor(address[] memory _owners, uint256 _required)
        public
        validRequirement(_owners.length, _required)
    {
        for (uint256 i = 0; i < _owners.length; i++) {
            isOwner[_owners[i]] = true;
        }
        owners = _owners;
        required = _required;
    }

    /// @dev Allows an owner to submit and confirm a transaction.
    /// @param destination Transaction target address.
    /// @param value Transaction ether value.
    /// @param data Transaction data payload.
    /// @return Returns transaction ID.

    function submitTransaction(
        address destination,
        uint256 value,
        bytes memory data
    ) public returns (uint256 transactionId) {
        require(isOwner[msg.sender]);
        transactionId = addTransaction(destination, value, data);
        confirmTransaction(transactionId);
    }

    /// @dev Allows an owner to confirm a transaction.
    /// @param transactionId Transaction ID.

    function confirmTransaction(uint256 transactionId) public {
        require(isOwner[msg.sender]);
        require(transactions[transactionId].destination != address(0));
        require(confirmations[transactionId][msg.sender] == false);
        confirmations[transactionId][msg.sender] = true;
        emit Confirmation(msg.sender, transactionId);
        executeTransaction(transactionId);
    }

    /// @dev Allows an owner to revoke a confirmation for a transaction.
    /// @param transactionId Transaction ID.
    function revokeConfirmation(uint256 transactionId) public {}

    /// @dev Allows anyone to execute a confirmed transaction.
    /// @param transactionId Transaction ID.

    function executeTransaction(uint256 transactionId) public {
        require(transactions[transactionId].executed == false);
        if (isConfirmed(transactionId)) {
            Transaction storage t = transactions[transactionId]; // using the "storage" keyword makes "t" a pointer to storage
            t.executed = true;
            (bool success, bytes memory returnedData) = t
                .destination
                .call
                .value(t.value)(t.data);
            if (success) emit Execution(transactionId);
            else {
                emit ExecutionFailure(transactionId);
                t.executed = false;
            }
        }
    }

    /// @dev Returns the confirmation status of a transaction.
    /// @param transactionId Transaction ID.
    /// @return Confirmation status.

    function isConfirmed(uint256 transactionId) public view returns (bool) {
        uint256 count = 0;
        for (uint256 i = 0; i < owners.length; i++) {
            if (confirmations[transactionId][owners[i]]) count += 1;
            if (count == required) return true;
        }
    }

    /// @dev Adds a new transaction to the transaction mapping, if transaction does not exist yet.
    /// @param destination Transaction target address.
    /// @param value Transaction ether value.
    /// @param data Transaction data payload.
    /// @return Returns transaction ID.

    function addTransaction(
        address destination,
        uint256 value,
        bytes memory data
    ) internal returns (uint256 transactionId) {
        transactionId = transactionCount;
        transactions[transactionId] = Transaction({
            destination: destination,
            value: value,
            data: data,
            executed: false
        });
        transactionCount += 1;
        emit Submission(transactionId);
    }
}
