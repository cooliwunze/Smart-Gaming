# Competitive Gaming Tournament Management Smart Contract

A comprehensive decentralized platform built on Stacks blockchain for organizing and managing competitive gaming tournaments with automated player registration, match orchestration, real-time score tracking, and merit-based prize distribution.

## Features

- **Automated Tournament Creation**: Create tournaments with customizable parameters
- **Player Registration System**: Secure registration with optional entry fees
- **Match Orchestration**: Schedule and manage competitive matches
- **Real-time Score Tracking**: Automatic score calculation and leaderboards
- **Merit-based Prize Distribution**: Proportional rewards based on performance
- **Transparent Governance**: Decentralized tournament management
- **Emergency Controls**: Platform maintenance and security features

## Smart Contract Architecture

### Core Data Structures

#### Tournament Registry
```clarity
{
  tournament-name: (string-ascii 50),
  tournament-description: (string-ascii 255),
  tournament-organizer: principal,
  current-phase: uint,
  registration-fee: uint,
  accumulated-prize-pool: uint,
  competition-start-block: uint,
  competition-end-block: uint,
  maximum-participant-count: uint,
  current-registered-count: uint
}
```

#### Participant Profiles
```clarity
{
  registration-block-height: uint,
  accumulated-score-points: uint,
  total-matches-participated: uint,
  total-victories-achieved: uint
}
```

#### Match Records
```clarity
{
  first-competitor: principal,
  second-competitor: principal,
  declared-winner: (optional principal),
  match-completion-block: (optional uint),
  competition-round-number: uint
}
```

## Getting Started

### Prerequisites
- Stacks blockchain node or connection to Stacks network
- STX tokens for transaction fees and entry fees
- Compatible wallet (Hiro Wallet, Xverse, etc.)

### Deployment
1. Deploy the smart contract to Stacks blockchain
2. The deployer automatically becomes the platform administrator
3. Contract is ready to accept tournament creations

## Usage Guide

### For Tournament Organizers

#### Creating a Tournament
```clarity
(contract-call? .tournament-contract create-new-tournament
  "Summer Championship"           ;; tournament name
  "Epic gaming competition"       ;; description
  u1000000                       ;; entry fee (1 STX)
  u1000                          ;; start block
  u2000                          ;; end block
  u50                            ;; max participants
)
```

#### Activating Competition
```clarity
(contract-call? .tournament-contract activate-tournament-competition u1)
```

#### Scheduling Matches
```clarity
(contract-call? .tournament-contract schedule-competition-match
  u1                             ;; tournament ID
  'SP1ABC...                     ;; first competitor
  'SP2DEF...                     ;; second competitor
  u1                             ;; round number
)
```

#### Recording Match Results
```clarity
(contract-call? .tournament-contract record-match-outcome
  u1                             ;; tournament ID
  u0                             ;; match ID
  'SP1ABC...                     ;; winner address
)
```

### For Players

#### Registering for Tournament
```clarity
(contract-call? .tournament-contract register-participant-for-tournament u1)
```

#### Claiming Prize Rewards
```clarity
(contract-call? .tournament-contract claim-tournament-prize-reward u1)
```

### Data Queries

#### Get Tournament Information
```clarity
(contract-call? .tournament-contract get-tournament-comprehensive-info u1)
```

#### Get Player Profile
```clarity
(contract-call? .tournament-contract get-participant-performance-profile u1 'SP1ABC...)
```

#### Get Match Details
```clarity
(contract-call? .tournament-contract get-competition-match-details u1 u0)
```

## Scoring System

- **Victory Points**: 3 points per win
- **Defeat Points**: 0 points per loss
- **Prize Distribution**: Proportional to accumulated points
- **Ranking**: Based on total score and win rate

## Prize Distribution

Prize pool distribution is merit-based and proportional:

```
Participant Prize = (Participant Points / Total Tournament Points) × Total Prize Pool
```

Example:
- Total Prize Pool: 50 STX
- Your Points: 9 (3 wins)
- Total Tournament Points: 45
- Your Prize: (9/45) × 50 = 10 STX

## Security Features

### Access Control
- **Platform Administrator**: Full system control
- **Tournament Organizer**: Tournament-specific management
- **Participants**: Registration and prize claiming only

### Input Validation
- Tournament name/description length limits
- Entry fee amount validation
- Participant capacity constraints
- Timeline validation (start/end blocks)
- Principal address verification

### Emergency Controls
- Platform maintenance mode
- Administrator role transfer
- Tournament phase management

## Analytics & Statistics

### Tournament Statistics
- Total registered participants
- Current prize pool
- Tournament phase status
- Total accumulated points

### Participant Analytics
- Match history
- Win/loss record
- Tournament ranking
- Win rate percentage
- Prize earnings

## Error Codes

| Code | Error | Description |
|------|-------|-------------|
| u100 | ERR-UNAUTHORIZED-ACCESS | Insufficient permissions |
| u101 | ERR-TOURNAMENT-DOES-NOT-EXIST | Invalid tournament ID |
| u102 | ERR-PLAYER-DUPLICATE-REGISTRATION | Already registered |
| u103 | ERR-REGISTRATION-PERIOD-CLOSED | Registration not open |
| u104 | ERR-MATCH-RECORD-NOT-FOUND | Invalid match ID |
| u105 | ERR-MATCH-RESULT-ALREADY-RECORDED | Match already completed |
| u106 | ERR-TOURNAMENT-CURRENTLY-ACTIVE | Tournament in wrong phase |
| u109 | ERR-INSUFFICIENT-WALLET-BALANCE | Not enough STX |
| u110 | ERR-PRIZE-FUNDS-ALREADY-CLAIMED | Prize already claimed |

## Configuration Constants

### Limits
- **Max Tournament Name**: 50 characters
- **Max Description**: 255 characters
- **Max Participants**: 1,000 players
- **Max Entry Fee**: 1,000,000 STX
- **Max Duration**: ~1 year (525,600 blocks)

### Scoring
- **Victory Points**: 3 points
- **Defeat Points**: 0 points
- **Minimum Participants**: 2 players