# 🎓 Tutorx - Peer Tutoring Protocol

A decentralized peer-to-peer tutoring platform built on the Stacks blockchain using Clarity smart contracts. Connect verified tutors with students and facilitate secure, transparent tutoring sessions with automatic payments.

## ✨ Features

- 👨‍🏫 **Tutor Registration & Verification**: Tutors can register and get verified by platform administrators
- 📚 **Session Booking**: Students can book tutoring sessions with verified tutors
- 💰 **Automatic Payments**: Secure escrow system with automatic tutor payments upon session completion
- ⭐ **Rating System**: Bidirectional rating system for tutors and students
- 🔧 **Tutor Management**: Tutors can update rates and toggle availability
- 💸 **Platform Fees**: Configurable platform fee structure (max 20%)

## 🚀 Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet for testing

### Installation

1. Clone the repository
2. Navigate to the project directory
3. Run Clarinet console:

```bash
clarinet console
```

## 📖 Usage Guide

### For Tutors 👨‍🏫

#### 1. Register as a Tutor
```clarity
(contract-call? .Tutorx register-tutor "John Doe" "Mathematics" u50)
```
- `name`: Your display name (max 50 characters)
- `subject`: Subject you teach (max 30 characters)  
- `hourly-rate`: Rate in microSTX per hour

#### 2. Get Verified
Only contract owner can verify tutors:
```clarity
(contract-call? .Tutorx verify-tutor u1)
```

#### 3. Update Your Rate
```clarity
(contract-call? .Tutorx update-tutor-rate u75)
```

#### 4. Toggle Availability
```clarity
(contract-call? .Tutorx toggle-tutor-status)
```

### For Students 📚

#### 1. Book a Session
```clarity
(contract-call? .Tutorx book-session u1 u2)
```
- `tutor-id`: ID of the verified tutor
- `duration-hours`: Session duration in hours

#### 2. Complete Session
Either student or tutor can mark session as completed:
```clarity
(contract-call? .Tutorx complete-session u1)
```

#### 3. Rate Your Tutor
```clarity
(contract-call? .Tutorx rate-session u1 u5 true)
```
- `session-id`: Session to rate
- `rating`: 1-5 stars
- `is-student`: true for student rating, false for tutor rating

### Payment Flow 💳

1. **Booking**: Student pays total cost (held in escrow)
2. **Session**: Tutoring session takes place
3. **Completion**: Either party marks session complete
4. **Payment**: Automatic payment to tutor (minus platform fee)

### Read-Only Functions 📊

#### Get Tutor Information
```clarity
(contract-call? .Tutorx get-tutor u1)
(contract-call? .Tutorx get-tutor-by-address 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

#### Get Session Details
```clarity
(contract-call? .Tutorx get-session u1)
```

#### Calculate Session Cost
```clarity
(contract-call? .Tutorx calculate-session-cost u1 u2)
```

#### Platform Information
```clarity
(contract-call? .Tutorx get-platform-fee)
(contract-call? .Tutorx get-contract-balance)
```

## 🏗️ Contract Architecture

### Data Structures

- **Tutors**: Profile information, ratings, earnings, verification status
- **Sessions**: Booking details, payment info, completion status, ratings
- **Mappings**: Efficient lookups for tutor addresses and session relationships

### Error Codes

| Code | Description |
|------|-------------|
| u100 | Not authorized |
| u101 | Tutor not found |
| u102 | Student not found |
| u103 | Session not found |
| u104 | Insufficient funds |
| u105 | Session already completed |
| u106 | Session not completed |
| u107 | Tutor not verified |
| u108 | Invalid rating (must be 1-5) |
| u109 | Already rated |
| u110 | Session already paid |

## 🔒 Security Features

- ✅ **Access Control**: Role-based permissions for different actions
- ✅ **Escrow System**: Funds held securely until session completion
- ✅ **Verification Required**: Only verified tutors can receive bookings
- ✅ **Double-spend Protection**: Prevents duplicate payments
- ✅ **Rating Integrity**: One rating per participant per session

## 🧪 Testing

Run the test suite:
```bash
clarinet test
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License.

## 🌟 Roadmap

- [ ] Multi-subject tutor support
- [ ] Session scheduling system
- [ ] Dispute resolution mechanism
- [ ] Tutor certification levels
- [ ] Group tutoring sessions
- [ ] Integration with external calendar systems


