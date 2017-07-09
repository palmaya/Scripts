#!/usr/bin/env swift

import Foundation

///Store information about users.
struct User {
    var uid: UInt32 = 0
    var credits: Int32 = 0
    var highscore: Int32 = 0
    var name: [UInt8] = []
    var currentGame : (() -> Int32)?
}

//
//Game of Chance
//
// Created by Katie Jones on 7/6/2017
//
//

let DATA_FILE = "chance.data"
let DEBUG_MODE_ON = false
var player : User! = User()

func size<T>(of value: T) -> Int {
    return MemoryLayout<T>.stride
}

func printd(_ message: CustomStringConvertible) {
    if DEBUG_MODE_ON {
        print(message)
    }
}

///This function is used to input the player name
func inputName() {
    var name = ""
    var inputCharacter = "\n"
    while inputCharacter == "\n" {
        inputCharacter = readLine(strippingNewline: false)!
    }
    name += inputCharacter.trimmingCharacters(in: CharacterSet.newlines)
    
    printd("\nName: \(name)")
    printd("Count: \(name.utf8.count)")
    printd("size of name: \(size(of: Array(name.utf8)))")
    var nameArray = Array(name.utf8)
    nameArray.append(0)
    player.name = nameArray
}

var playerName : String {
    return String(bytes: player.name, encoding: .utf8)!
}

func beginGame() {
    var choice: Int32 = 0
    var lastGame: Int32 = 0
    
    if getPlayerData() == -1 {
        registerNewPlayer()
    }
    
    while choice != 7 {
        print("\nGame of Chance Menu")
        print("1 - Play the Pick a Number game")
        print("2 - Play the No Match Dealer game")
        print("3 - Play the Find the Ace game")
        print("4 - View current high score")
        print("5 - Change your user name")
        print("6 - Reset your account at 100 credits")
        print("7 - Quit")
        print(String(format: "\n[Name: %@]", playerName))
        print(String(format: "[You have %u credits] ->", player.credits))
        choice = scanf()
        
        if choice < 1 || choice > 7 {
            print(String(format: "[!!] The number %d is an invalid selection.\n", choice))
        }
        else if choice < 4 {
            if choice != lastGame {
                if choice == 1 {
                    player.currentGame = pickANumber
                } else if choice == 2 {
                    player.currentGame = dealerNoMatch
                } else {
                    player.currentGame = findTheAce
                }
                lastGame = choice
            }
            playGame()
        }
        else if choice == 4 {
            showHighScore()
        }
        else if choice == 5 {
            print("\nChange user name")
            print("Enter your new name: ")
            inputName()
            print("\nYour name has been changed")
        }
        else if choice == 6 {
            print("\nYour account has been reset with 100 credits.")
            player.credits = 100
        }
    }
    updatePlayerData()
    print("\nThanks for playing! Bye.")
}

///This function reads the player data for the current uid
///from the file. It returns -1 if it is unable to find player
///data for the current uid.
func getPlayerData() -> Int {
    var fd : Int32
    var uid : UInt32
    var readBytes : Int
    var entry = User()
    var readUid : UInt32 = 0
    var readInt : Int32 = 0
    uid = getuid()
    var totalBytesRead : Int = 0
    
    fd = open(DATA_FILE, O_RDONLY)
    if fd == -1 {
        return -1
    }
    defer { close(fd) }
    
    let strPointer : UnsafeMutablePointer<CChar> =  UnsafeMutablePointer<CChar>.allocate(capacity: 100)
    
    repeat {
        readBytes = read(fd, &readUid, 4)
        printd("\ngetPlayerData() read \(readBytes) bytes")
        printd(readUid)
        totalBytesRead += readBytes
        
    } while readBytes > 0 && readUid != uid
    
    entry.uid = readUid
    
    //read credits
    readBytes = read(fd, &readInt, 4)
    totalBytesRead += readBytes
    if readBytes == 4 {
      entry.credits = readInt
    }
    
    //read high score
    readBytes = read(fd, &readInt, 4)
    totalBytesRead += readBytes
    if readBytes == 4 {
        entry.highscore = readInt
    }
    
    //read name
    readBytes = read(fd, strPointer, 8)
    totalBytesRead += readBytes
    
    if readBytes >= 8 {
        printd("string pointer data: \(strPointer.pointee)")
        let str = String(cString: strPointer)
        if totalBytesRead >= 20 {
            printd("String: \(str)")
            var nameArray = Array(str.utf8)
            nameArray.append(0)
            entry.name = nameArray
            
            player = entry
            printd("user: \(entry), total bytes read: \(totalBytesRead) ")
            return 1
        }
    }
    
    print("\nno user, read bytes \(readBytes)")
    return -1
}

///This is the new user registration function.
///It will create a new player account and append it to the file
func registerNewPlayer() {
    var fd : Int32
    
    print("-=-={ New Player Registration }=-=-")
    print("Enter your name: ")
    inputName()
    
    player.uid = getuid()
    player.highscore = 100
    player.credits = 100
    
    fd = open(DATA_FILE, O_WRONLY | O_CREAT | O_APPEND, S_IRUSR | S_IWUSR)
    if fd == -1 {
        fatal(error: "\nError in registerNewPlayer() while opening file")
    }
    printd("size of user struct: \(size(of: player))")
    write(fd, &player.uid, size(of: player.uid))
    close(fd)
    
    print(String(format: "\nWelcome to the Game of Chance %@.", playerName))
    print(String(format: "You have been given %u credits.", player.credits))
}

///This function writes the current player data to the file.
///It is used primarily for updating the credits after games.
func updatePlayerData() {
    var fd : Int32
    var readUid : UInt32 = 0
    var burnedByte = CChar16()
    
    fd = open(DATA_FILE, O_RDWR)
    if fd == -1 {
        fatal(error: "\nError in updatePlayerData() while opening file")
    }
    read(fd, &readUid, 4)
    printd("\nread Uid in updatePlayerdata: \(readUid)")
    while readUid != player.uid {
        printd("- read while loop in updatePlayerData")
        for _ in 0..<size(of: player) - 4 { //Read through the rest of that struct.
            read(fd, &burnedByte, 1)
        }
        read(fd, &readUid, 4) //Read the uid from the next struct.
        printd("next - read Uid in updatePlayerdata: \(readUid)")
    }
    printd("writing user data")
    write(fd, &player.credits, size(of: player.credits))  //4
    write(fd, &player.highscore, size(of: player.highscore))  //4
    write(fd, &player.name, size(of: player.name))  //8
    close(fd)
}

///This function will display the current high score and
///the name of the person who set that high score.
func showHighScore() {
    var readBytes : Int
    var readUid : UInt32 = 0
    var readInt : Int32 = 0
    var totalBytesRead : Int = 0
    
    let strPointer : UnsafeMutablePointer<CChar> =  UnsafeMutablePointer<CChar>.allocate(capacity: 100)
    
    
    var topScore : Int32 = 0
    var topName = ""
    var entry : User
    var fd : Int32
    
    print("\n===============| HIGH SCORE |===============")
    fd = open(DATA_FILE, O_RDONLY)
    if fd == -1 {
        fatal(error: "Error in showHighScore() while opening file")
    }
    
   repeat {
    totalBytesRead = 0
    entry = User()
    
    //read uid
    readBytes = read(fd, &readUid, 4)
    printd("\nreadPlayer() read \(readBytes) bytes")
    printd(readUid)
    totalBytesRead += readBytes
    if readBytes == 4 {
        entry.uid = readUid
    }
    
    //read credits
    readBytes = read(fd, &readInt, 4)
    printd(readInt)
    totalBytesRead += readBytes
    if readBytes == 4 {
        entry.credits = readInt
    }
    
    //read high score
    readBytes = read(fd, &readInt, 4)
    printd(readInt)
    totalBytesRead += readBytes
    if readBytes == 4 {
        entry.highscore = readInt
    }
    
    //read name
    readBytes = read(fd, strPointer, 8)
    totalBytesRead += readBytes
    printd("readBytes for str: \(readBytes)")
    if readBytes >= 8 {
        printd("string pointer data: \(strPointer.pointee)")
        let str = String(cString: strPointer)
        if totalBytesRead >= 20 {
            printd("String: \(str)")
            var nameArray = Array(str.utf8)
            nameArray.append(0)
            entry.name = nameArray
            
            printd("user: \(entry), total bytes read: \(totalBytesRead) ")
        }
    }
    
    if entry.highscore > topScore {
        topScore = entry.highscore
        topName = String(describing: entry.name)
    }
    
   } while readBytes > 0
    
    close(fd)
    if topScore > player.highscore {
        print(String(format: "%@ has the high score of %u", topName, topScore))
    } else {
        print(String(format: "You currently have the high score of %u credits!", player.highscore))
    }
    print("==========================================")
}

///This function simply awards the jackpot for the Pick a Number game.
func jackpot() {
    print("*+*+*+*+*+* JACKPOT *+*+*+*+*+*")
    print("You have won the jackpot of 100 credits!")
    player.credits += 100
}

///This function prints the 3 cards for the Find the Ace game.
///It expects a message to display, a pointer to the cards array,
///and the card the user has picked as input. If the user_pick is
//-1, then the selection numbers are displayed.
func printCards(message: String, cards: [String], userPick: Int32) {
    print(String(format: "\t*** %@ ***", message))
    print(" \t._.\t._.\t._.")
    print(String(format: "Cards:\t|%@|\t|%@|\t|%@|\n\t", cards[0], cards[1], cards[2]))
    if userPick == -1 {
        print(" \t 1 \t 2 \t 3\n")
    } else {
        var tab = ""
        for _ in 0..<userPick {
            tab += "\t"
        }
        print("\(tab) ^-- your pick\n")
    }
}

///This function inputs wagers for both the No Match Dealer and
///Find the Ace games. It expects the available credits and the
///previous wager as arguments. The previous_wager is only important
///for the second wager in the Find the Ace game. The function
///returns -1 if the wager is too big or too little, and it returns
///the wager amount otherwise.
func takeWager(availableCredits: Int32, previousWager: Int32) -> Int32 {
    var wager: Int32, totalWager : Int32 = 0
    
    print(String(format: "How many of your %d credits would you like to wager? ", availableCredits))
    wager = scanf()
    if wager < 1 {
        print("Nice try, but you must wager a positive number!")
        return -1
    }
    totalWager = previousWager + wager
    if totalWager > availableCredits {
        print(String(format: "Your total wager of %d is more than you have!", totalWager))
        print(String(format: "You only have %d available credits, try again.", availableCredits))
        return -1
    }
    return wager
}

///This function contains a loop to allow the current game to be
///played again. It also writes the new credit totals to file
///after each game is played.
func playGame() {
    var playAgain = true
    var selection : String
    
    while playAgain {
        //print(String(format: "\n[DEBUG] currentGame pointer @ %p\n", player.currentGame))
        if let currentGame = player.currentGame, currentGame() != -1 {
            if player.credits > player.highscore {
                player.highscore = player.credits
            }
            print(String(format: "You now have %u credits\n", player.credits))
            updatePlayerData()
            print("Would you like to play again? (y/n)  ")
            selection = "\n"
            while selection == "\n" {
                selection = readLine()!
            }
            if (selection == "n") {
                playAgain = false
            }
        }
        else {
            playAgain = false
        }
    }
}

///This function is the Pick a Number game.
///It returns -1 if the player doesn't have enough credits.
func pickANumber() -> Int32 {
    var pick : Int32, winningNumber : Int32 = 0
    
    print("\n####### Pick a Number #######\n")
    print("This game costs 10 credits to play. Simply pick a number\n")
    print("between 1 and 20, and if you pick the winning number, you\n")
    print("will win the jackpot of 100 credits!\n\n")
    winningNumber = Int32(arc4random_uniform(20) + 1)
    if player.credits < 10 {
        print(String(format: "You only have %d credits. That's not enough to play!\n\n", player.credits))
        return -1
    }
    player.credits -= 10
    print("10 credits have been deducted from your account.\n")
    print("Pick a number between 1 and 20: ")
    pick = scanf()
    
    print(String(format: "The winning number is %d\n", winningNumber))
    if pick == winningNumber {
        jackpot()
    } else {
        print("Sorry, you didn't win.\n")
    }
    return 0
}

///This is the No Match Dealer game.
///It returns -1 if the player has 0 credits.
func dealerNoMatch() -> Int32 {
    var numbers = [Int]()
    var wager : Int32 = -1
    var match = -1
    var j = 0
    
    print("\n::::::: No Match Dealer :::::::\n")
    print("In this game, you can wager up to all of your credits.\n")
    print("The dealer will deal out 16 random numbers between 0 and 99.\n")
    print("If there are no matches among them, you double your money!\n\n")
    
    if player.credits == 0 {
        print("You don't have any credits to wager!\n\n")
        return -1
    }
    while wager == -1 {
        wager = takeWager(availableCredits: player.credits, previousWager: 0)
    }
    print("\t\t::: Dealing out 16 random numbers :::\n")
    for i in 0..<16 {
        numbers.append(Int(arc4random_uniform(100)))
        print(String(format: "%2d\t", numbers[i]))
        if i%8 == 7 {               //Print a line break every 8 numbers.
            print("\n")
        }
    }
    for i in 0..<15 {
        j = i + 1
        while j < 16 {
            if numbers[i] == numbers[j] {
                match = numbers[i]
            }
            j += 1
        }
    }
    if match != -1 {
        print(String(format: "The dealer matched the number %d!\n", match))
        print(String(format: "You lose %d credits.\n", wager))
        player.credits -= wager
    } else {
        print(String(format: "There were no matches! You win %d credits!\n", wager))
        player.credits += wager
    }
    return 0
}

///This is the Find the Ace game.
///It returns -1 if the player has 0 credits.
func findTheAce() -> Int32 {
    var ace : Int32
    //totalWager : Int
    var invalidChoice = false
    var pick : Int32, wagerOne : Int32 = -1, wagerTwo: Int32 = -1
    var choiceTwo : String
    var cards = ["X", "X", "X"]
    
    ace = Int32(arc4random_uniform(3))
    
    print("\n******* Find the Ace *******\n")
    print("In this game, you can wager up to all of your credits.\n")
    print("Three cards will be dealt out, two queens and one ace.\n")
    print("If you find the ace, you will win your wager.\n")
    print("After choosing a card, one of the queens will be revealed.\n")
    print("At this point, you may either select a different card or\n")
    print("increase your wager.\n\n")
    
    if player.credits == 0 {
        print("You don't have any credits to wager!\n\n")
        return -1
    }
    
    while wagerOne == -1 {
        wagerOne = takeWager(availableCredits: player.credits, previousWager: 0)
    }
    
    printCards(message: "Dealing cards", cards: cards, userPick: -1)
    pick = -1
    while pick < 1 || pick > 3 {
        print("Select a card: 1, 2, or 3   ")
        pick = scanf()
    }
    pick -= 1
    var i = 0
    while Int32(i) == ace || Int32(i) == pick {
        i += 1
    }
    cards[i] = "Q"
    printCards(message: "Revealing a queen", cards: cards, userPick: pick+1)
    invalidChoice = true
    while invalidChoice {
        print("Would you like to:\n[c]hange your pick\tor\t[i]ncrease your wager?\n")
        print("Select c or i:   ")
        choiceTwo = "\n"
        while choiceTwo == "\n" {
            choiceTwo = readLine()!
        }
        if choiceTwo == "i" {
            invalidChoice = false
            while wagerTwo == -1 {
                wagerTwo = takeWager(availableCredits: player.credits, previousWager: wagerOne)
            }
        }
        if choiceTwo == "c" {
            i = 0
            invalidChoice = false
            while Int32(i) == pick || cards[i] == "Q" {
                i += 1
            }
            pick = Int32(i)
            print(String(format: "Your card pick has been changed to card %d\n", pick+1))
        }
    }
    
    for i in 0..<3 {
        if Int(ace) == i {
            cards[i] = "A"
        } else {
            cards[i] = "Q"
        }
    }
    printCards(message: "End result", cards: cards, userPick: pick+1)
    
    if pick == ace {
        print(String(format: "You have won %d credits from your first wager\n", wagerOne))
        player.credits += wagerOne
        if wagerTwo != -1 {
            print(String(format: "and an additional %d credits from your second wager!\n", wagerTwo))
            player.credits += wagerTwo
        }
    } else {
        print(String(format: "You have lost %d credits from your first wager\n", wagerOne))
        player.credits -= wagerOne
        if wagerTwo != -1 {
            print(String(format: "and an additional %d credits from your second wager!\n", wagerTwo))
            player.credits -= wagerTwo
        }
    }
    return 0
}

func scanf() -> Int32 {
    guard let result = readLine(strippingNewline: true) else {
        return 0
    }
    return Int32(result, radix: 10) ?? 0
}

func fatal(error: String) {
    print(error)
    fatalError(error)
}


if CommandLine.arguments.count > 1 {
    exit(-1)
} else {
    beginGame()
    exit(0)
}
