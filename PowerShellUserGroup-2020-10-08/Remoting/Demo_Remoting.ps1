break

#region Allgemein

# Wieviele Cmdlets haben einen -Computername Parameter
# Mit diesen Cmdlet kann man zwar Computer remote
# managen, dabei wird aber meist RPC (DCOM) benutzt.
# Dies ist nicht Firewallfreundlich (Stichwort Dynamic Ports).
# Gilt nur f�r Windows PowerShell PowerShell 5.1
Get-Help -Name * -Parameter 'ComputerName'

# Also am besten auf diese Cmdlets umsteigen die den Parameter Session
# haben
Get-Command -CommandType Cmdlet | Where-Object { $_.definition -like "*session*" }

#endregion

#region Dokumentation
# Remoting ist sehr gut dokumentiert
# SWITCH TO PWSH
Get-Help about_Remote*
#endregion

#region Enable-PSRemoting

# Damit WinRM funktioniert ben�tigt man
# folgendes:
# Der Dienst WinRM muss gestartet sein (Beim Server automatisch, beim
# Client nicht)
# Es muss ein listener eingerichtet sein.
# Die Windows Firewall muss konfiguriert sein
# alles dies wird mit folgendem Cmdlet erledigt:
Enable-PSRemoting

# Bekommen wir hier eine Fehlermeldung, dass wir Netzwerkkarten
# mit einem Public Profil haben, f�hren wir folgendes Cmdlet aus
Enable-PSRemoting -SkipNetworkProfileCheck

# Nun k�nnen wir uns den Listener anzeigen lassen:
Get-ChildItem WSMan:\localhost\Listener

# Nun habe ich folgende Endpoints
Get-PSSessionConfiguration

# Verbindet man sich auf einen Computer �ber PowerShell Remoting,
# so verbindet man sich immer auf diesen Endpunkt: microsoft.powershell

#endregion

#region GPO

# Computer Configuration / Administrative Templates / Windows Components
# Windows Remote Management (WinRM) / WinRM Service
gpedit.msc
#endregion

#region Sicherheit
# Remoting kann nur als Administrator (Dom�ne oder Lokaler Administrator)
# ausgef�hrt werden. Dies ist im Standardendpoint so hinterlegt.
# Man kann aber auch mit einem Credential arbeiten um die Session als ein
# andere Benutzer auszuf�hren.
Get-Help Enter-PSSession -ShowWindow

# Vor allem wenn man sich in einem Workgroup environment befindet ist
# folgendes besonders wichtig. Hier�ber wird gesteuert welcher
# Client / IP-Range sich auf den Client per PowerShell Remoting verbinden
# darf.
Get-ChildItem wsman:\localhost\client\TrustedHosts

# Um jetzt einen Eintrag hinzuzuf�gen f�hrt man folgendes Cmdlet aus
# Bsp. Client Name
Set-Item wsman:\localhost\client\trustedhosts Google_* -Force
Get-ChildItem wsman:\localhost\client\TrustedHosts

# Bsp.: IP-Range
Set-Item wsman:\localhost\client\trustedhosts 10.10.10.* -Force -Concatenate
Get-ChildItem wsman:\localhost\client\TrustedHosts

# Bsp. Einzelner Host mit IP
Set-Item wsman:\localhost\client\trustedhosts 192.168.2.34 -Force -Concatenate

# Dies sollte man nur machen wenn man sich in einer Testumgebung befindet:
# Man vertraut hier allen Hosts (Ist in einer AD Umgebung aber auch nicht gef�hlich)
Set-Item wsman:\localhost\client\trustedhosts * -Force
Get-ChildItem wsman:\localhost\client\TrustedHosts

# Um den Defaultwert wiederherzustellen:
Set-Item wsman:\localhost\client\trustedhosts '' -Force
Get-ChildItem wsman:\localhost\client\TrustedHosts

#endregion

#region 1:1 Remoting

#region Weg 1: Erstellen der Session
$session = New-PSSession -ComputerName DC2
Get-PSSession

# Nun steigen wir in die Session ein
Enter-PSSession -Session $session

# Auf welchem PC befinden wir uns jetzt? (Wir sehen
# das am ver�nderten Prompt.)
$env:COMPUTERNAME

# Mit welchem Benutzer sind wir angemeldet
$PSSenderInfo

# Normalen Befehl ausf�hren
Get-Process | Sort-Object ws -desc | Select-Object -first 3

# Session wieder verlassen
Exit-PSSession

# Session ist aber immernoch offen
Get-PSSession

# Immer die Sessions schlie�en ist einfach sauberer vom Vorgehen
Remove-PSSession -Session $session
#endregion

#region Weg 2: Computername

# Das 1:1 Remoting ist auch �ber den Parameter Computername m�glich
Enter-PSSession -ComputerName DC2

# Auf welchem PC befinden wir uns jetzt? (Wir sehen
# das am ver�nderten Prompt.)
$env:COMPUTERNAME

# Mit welchem Benutzer sind wir angemeldet
$PSSenderInfo

# Normalen Befehl ausf�hren
Get-Process | Sort-Object ws -desc | Select-Object -first 3

# Session wieder verlassen
Exit-PSSession

# Die Session ist aber nun beendet und nicht mehr offen.
Get-PSSession

#enregion

#endregion

# Warum nutzt man Sessions? Wegen der Wiederverwendbarkeit.
# Benutze ich bei Enter-PSSession nur den Computername-Parameter
# so muss ich mich erneut mit Enter-PSSession -Computername verbinden.
# Kommt auf die Situation an. Beim Skripting wird das beispielsweise
# wichtig.

#region Linux

$session = New-PSSession -HostName 10.0.0.6 -UserName azureuser
Get-PSSession

# Nun steigen wir in die Session ein
Enter-PSSession -Session $session

# Mit welchem Benutzer sind wir angemeldet
$PSSenderInfo

# Normalen Befehl ausf�hren
Get-Process | Sort-Object ws -desc | Select-Object -first 3

# Session wieder verlassen
Exit-PSSession

# Session ist aber immernoch offen
Get-PSSession

# Immer die Sessions schlie�en ist einfach sauberer vom Vorgehen
Remove-PSSession -Session $session

# Enter-PSSesssion funktioniert auch
Enter-PSSession -HostName 10.0.0.6 -UserName azureuser

# Mit welchem Benutzer sind wir angemeldet
$PSSenderInfo

# Normalen Befehl ausf�hren
Get-Process | Sort-Object ws -desc | Select-Object -first 3

# Session wieder verlassen
Exit-PSSession

#endregion

#endregion

#region 1:n Remoting

# Hier werden ein Befehl / mehrere Befehle / Skripte / Funktionen gegen einen oder
# mehrere Clients ausgef�hrt

#region Weg 1: Mit Sessions arbeiten
$computers = 'DC2', 'Win10'

# Hiermit kann man mehrere Session gleichzeitig �ffnen
$sessions = New-PSSession -ComputerName $computers

# Das Cmdlet das man nun ben�tigt (die allzweckwaffe) ist
# Invoke-Command
Get-Help Invoke-Command -ShowWindow

# Ergebnis auf die Console ausgeben (In diesem Fall hole ich
# mir die Eventlogs von 2 Rechnern
Invoke-Command -Session $sessions -ScriptBlock {
    Get-EventLog -LogName Application -Newest 3
}

# Man kann die R�ckgabe auch in einer Variable speichern
$logs = Invoke-Command -Session $sessions -ScriptBlock {
    Get-EventLog -LogName Application -Newest 3
}

# Ausgabe
$logs

# Einen Ordner auf allen Rechnern erstellen
Invoke-Command -Session $sessions -ScriptBlock {
    New-Item -ItemType Directory -Path C:\ -Name TestRemoting
}

# Schaut man sich nun das R�ckgabeobjekt genauer an
$logs | Get-Member

# so sieht man mehrere Dinge:
# Es handelt sich hier um kein richtiges .Net Objekt sondern um ein Deserialized
# .Net-Objekt, d.h. wir haben keine Live-Daten vor uns sondern nur die Daten
# die wir zu diesem Zeitpunkt abgeholt haben.

# N�chster Punkt ist, dass wir eine Eigenschaft PSComputerName haben. Somit
# ist immer ersichtlich von welchem Client wir welche Informationen erhalten haben.

# Alle Sessions wieder entfernen
Get-PSSession | Remove-PSSession

#endregion

#region Weg 2: Mit ComputerName arbeiten
$computers = 'DC2', 'Win10'

Invoke-Command -ComputerName $computers -ScriptBlock {
    Get-EventLog -LogName Application -Newest 3
}

# Man kann die R�ckgabe auch in einer Variable speichern
$logs = Invoke-Command -ComputerName $computers -ScriptBlock {
    Get-EventLog -LogName Application -Newest 3
}

# Ausgabe
$logs

# Einen Ordner auf allen Rechnern erstellen
Invoke-Command -ComputerName $computers -ScriptBlock {
    New-Item -ItemType Directory -Path C:\ -Name TestRemoting
}

# Schaut man sich nun das R�ckgabeobjekt genauer an
$logs | Get-Member
#endregion

#region linux

#region Weg 1: Mit Sessions arbeiten
$computers = 'DC2', '10.0.0.6'

# Hiermit kann man mehrere Session gleichzeitig �ffnen
$sessions = New-PSSession -HostName $computers -UserName azureuser

# Das Cmdlet das man nun ben�tigt (die allzweckwaffe) ist
# Invoke-Command
Get-Help Invoke-Command -ShowWindow

# Ergebnis auf die Console ausgeben (In diesem Fall hole ich
# mir die Eventlogs von 2 Rechnern
Invoke-Command -Session $sessions -ScriptBlock {
    Get-Process | Select-Object -First 3
}

# Man kann die R�ckgabe auch in einer Variable speichern
$logs = Invoke-Command -Session $sessions -ScriptBlock {
    Get-Process | Select-Object -First 3
}

# Ausgabe
$logs

# Einen Ordner auf allen Rechnern erstellen
# Neuen Variablen in PowerShell 7
# Wird der Befehl auf Linux ausgef�hrt ist $IsLinux $true
# Wird der Befehl auf Windows ausgef�hrt ist $IsWindows $true
Invoke-Command -Session $sessions -ScriptBlock {

    if ($IsLinux)
    {
        New-Item -ItemType File -Path "/home/azureuser/testfile"
    }
    else
    {
        New-Item -ItemType File -Path "C:\Users\Default\Desktop\testfile"
    }
}

# Schaut man sich nun das R�ckgabeobjekt genauer an
$logs | Get-Member

# so sieht man mehrere Dinge:
# Es handelt sich hier um kein richtiges .Net Objekt sondern um ein Deserialized
# .Net-Objekt, d.h. wir haben keine Live-Daten vor uns sondern nur die Daten
# die wir zu diesem Zeitpunkt abgeholt haben.

# N�chster Punkt ist, dass wir eine Eigenschaft PSComputerName haben. Somit
# ist immer ersichtlich von welchem Client wir welche Informationen erhalten haben.

# Alle Sessions wieder entfernen
Get-PSSession | Remove-PSSession

#endregion

#region Weg 2: Mit ComputerName arbeiten
$computers = 'DC2', '10.0.0.6'

Invoke-Command -HostName $computers -UserName azureuser -ScriptBlock {
    Get-Process | Select-Object -First 3
}

# Man kann die R�ckgabe auch in einer Variable speichern
$logs = Invoke-Command -HostName $computers -UserName azureuser -ScriptBlock {
    Get-Process | Select-Object -First 3
}

# Ausgabe
$logs

# Einen Ordner auf allen Rechnern erstellen
Invoke-Command -HostName $computers -UserName azureuser -ScriptBlock {
    if ($IsLinux)
    {
        New-Item -ItemType File -Path "/home/azureuser/testfile"
    }
    else
    {
        New-Item -ItemType File -Path "C:\Users\Default\Desktop\testfile"
    }
}

# Schaut man sich nun das R�ckgabeobjekt genauer an
$logs | Get-Member
#endregion

#endregion

#endregion

#region Implicit Remoting

# Dies ist meiner Meinung nach sehr interessant. Es werden
# Cmdlets die gar nicht auf deinem Computer installiert sind
# remote eingebunden. Diese kann man dann lokal sehen und
# ausf�hren. Sie werden aber nicht auf dem Client ausgef�hrt,
# sondern auf der Maschine von der sie importiert wurden.
# Man nennt dies auch ProxyFunctions.

# Beispiel AD Cmdlets

# 1. Session erstellen
$session = New-PSSession -ComputerName DC2

# 2. In diese Session das Modul Active Directory importieren
Invoke-Command -Session $session -ScriptBlock {
    Import-Module -Name ActiveDirectory
}

# 3. Die Session importieren (Nur das Modul was importiert wurde, sonst bekommt man
# eine Menge Fehlermeldungen)
Import-PSSession -Prefix ADREM -Session $session -Module ActiveDirectory

# 4. Cmdlets anzeigen lassen
Get-Command *ADREM*

# 5. Cmdlet ausprobieren
Get-ADREMADUser -Filter * | Select-Object -First 1

# 6. Wenn Fertig Session wieder l�schen
Remove-PSSession -Session $session

# 7. Cmdlets sind nun nicht mehr da
Get-Command *ADREM*

#endregion