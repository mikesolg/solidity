//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.14;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

struct Voter {
    bool isRegistered; 
    bool hasVoted;
    uint votedProposalId;
}

struct Proposal {
    string description;
    uint voteCount;
}

enum WorkflowStatus {  
    RegisteringVoters,
    ProposalsRegistrationStarted,
    ProposalsRegistrationEnded,
    VotingSessionStarted,
    VotingSessionEnded,
    VotesTallied
}

contract Voting is Ownable {
    // allow multiple proposal / voting sessions 
    // when sessionId changes, a new series of proposals and votes is available
    uint public currentSessionId;

    // potential voters - please note that registration is stored in sessionId 0
    // sessionId => address => voter 
    mapping(uint=>mapping(address=>Voter)) public voters;
    
    // sessionId => proposalId => proposal
    // proposal Id 0 is an empty proposal which is the winner in case of equality between votes
    mapping(uint => mapping(uint=>Proposal)) public proposals;

    // Id of the last created proposal inside this session 
    uint public lastProposalId;
    uint public winningProposalId;

    // current workflow status
    WorkflowStatus public currentStatus;

    event VoterRegistered(address voterAddress); 
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted (address voter, uint proposalId);

    modifier onlyRegistered(address _addr) {
        // registering is stored in first voting session only 
        require(voters[0][msg.sender].isRegistered, "Only registered users can interact with this contract.");
        _;
    }

   function registerUser(address _addr) public onlyOwner {
        require(currentStatus==WorkflowStatus.RegisteringVoters, "Registrations not opened.");
        // registration is stored in first session but new addresses may be added in later sessions 
        voters[0][_addr].isRegistered=true;
        emit VoterRegistered(_addr);
    }

    function startRegisteringProposals() public onlyOwner {
        require (currentStatus==WorkflowStatus.RegisteringVoters, "Expected current status is Registering Users");
        currentStatus=WorkflowStatus.ProposalsRegistrationStarted;
        emit WorkflowStatusChange(WorkflowStatus.RegisteringVoters, WorkflowStatus.ProposalsRegistrationStarted);
    }

    function stopRegisteringProposals() public onlyOwner {
        require (currentStatus==WorkflowStatus.ProposalsRegistrationStarted, "Expected current status is Proposals Registrations Started");
        currentStatus=WorkflowStatus.ProposalsRegistrationEnded;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationStarted, WorkflowStatus.ProposalsRegistrationEnded);
    }

    function startVoting() public onlyOwner {
        require (currentStatus==WorkflowStatus.ProposalsRegistrationEnded, "Expected current status is Proposals Registrations Ended");
        currentStatus=WorkflowStatus.VotingSessionStarted;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationEnded, WorkflowStatus.VotingSessionStarted);
    }

    function stopVoting() public onlyOwner {
        require (currentStatus==WorkflowStatus.VotingSessionStarted, "Expected current status is Voting Session Started");
        currentStatus=WorkflowStatus.VotingSessionEnded;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionStarted, WorkflowStatus.VotingSessionEnded);
    }

    function registerProposal(string calldata _descr) public onlyRegistered(msg.sender) {
        require (currentStatus==WorkflowStatus.ProposalsRegistrationStarted, "Proposal registrations not opened");
        // create a new proposal inside current session
        proposals[currentSessionId][++lastProposalId]=Proposal(_descr, 0);
        emit ProposalRegistered(lastProposalId);
    }

    // a user voting for propId 0 is considered a blank vote with the 
    // only effect that he cannot vote inside this voting session anymore
    function vote(uint _propId) public onlyRegistered(msg.sender)  {
        require (currentStatus==WorkflowStatus.VotingSessionStarted, "Voting session not opened");
        require (!voters[currentSessionId][msg.sender].hasVoted, "You have already voted !");
        require (_propId <= lastProposalId, "This proposal does not exist");
        voters[currentSessionId][msg.sender].hasVoted=true;
        voters[currentSessionId][msg.sender].votedProposalId=_propId;
        proposals[currentSessionId][_propId].voteCount++;
        emit Voted(msg.sender, _propId);
    }

    function publishResults() public onlyOwner { 
        require (currentStatus==WorkflowStatus.VotingSessionEnded, "Expected current status is Voting Session Ended");
        
        // max vote number found for a proposal
        uint max;

        // use this memory variable to prevent multiple storage updates
        uint winningIndex;

        // 0 doesnt need to be considered as it is used for equalities
        for (uint i=1;i<=lastProposalId;i++) {
            if (proposals[currentSessionId][i].voteCount==max) {
                // equality => no winner
                winningIndex=0; 
            } else if (proposals[currentSessionId][i].voteCount>max) {
                winningIndex=i;
                max=proposals[currentSessionId][i].voteCount;
            }
        }
        
        // update public member - value stays 0 in case of equality
        if (winningIndex!=0)
            winningProposalId=winningIndex;

        currentStatus=WorkflowStatus.VotesTallied;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionEnded, WorkflowStatus.VotesTallied);
    }
 
    // whatever the current status, the admin can start a new voting session
    function createNewSession() public onlyOwner {
        currentStatus=WorkflowStatus.RegisteringVoters;
        // index of the new session with no proposals and votes
        currentSessionId++;
        lastProposalId=0;
        winningProposalId=0;
    }
}
