#!/usr/bin/perl 
# nagios -epn

# ============================================================================

# based on $Id: table.pl,v 4.2 2002/05/06 12:30:37 dtown Rel $

# Copyright (c) 2000-2002 David M. Town <dtown@cpan.org>
# All rights reserved.

# This program is free software; you may redistribute it and/or modify it
# under the same terms as Perl itself.

# ============================================================================

# based on check_sfp_cisco.pl
# modified for Juniper by Jonas Frey <jf@probe-networks.de>
# Version 1.0  2019-08-31
#
# This plugin checks SFP optical power levels TX/RX on juniper HW.
#
#use strict;
use Data::Dump qw(dump);
use Net::SNMP qw(snmp_dispatcher oid_lex_sort);
use Class::Struct;
use Getopt::Long;
my $rh_params = {};
GetOptions($rh_params,
  'hostname:s',
  'community:s',
  'type:s',
  'help',
);
my $UNIDAD;
my $filtro;
my $TEXTO_SALIDA="";
my $SALIDA=0;
$rh_params->{help} && imprime_ayuda( 0 );
unless ( defined $rh_params->{hostname}
         && defined $rh_params->{type}
       ) {
    imprime_ayuda( 1 );
}


	if($rh_params->{type} eq "bias" ){$UNIDAD="ma";$filtro="Bias Current Sensor";
	} elsif($rh_params->{type} eq "temp") {$UNIDAD="Celsius";$filtro="Temperature Sensor";}
	elsif($rh_params->{type} eq "power") {$UNIDAD="dbm";$filtro="xe|ge";}
	elsif($rh_params->{type} eq "supply") {$UNIDAD="Volts";$filtro="Supply Voltage Sensor";}
	else {imprime_ayuda( 1 );}
#print $filtro;
# Create the SNMP session 
my ($session, $error) = Net::SNMP->session(
   -hostname  => $rh_params->{hostname} || 'localhost',
   -community => $rh_params->{community} || 'public',
   -port      =>  161,
   -version   => 'snmpv2c'
);

# Was the session created?
if (!defined($session)) {
   printf("ERROR: %s.\n", $error);
   exit 1;
}

my $ifTable_Descr = '.1.3.6.1.2.1.2.2.1.2';

my $ifTable_High_tx_warn = '.1.3.6.1.4.1.2636.3.60.1.1.1.1.19';
my $ifTable_High_rx_warn = '.1.3.6.1.4.1.2636.3.60.1.1.1.1.11';
my $ifTable_Low_tx_warn = '.1.3.6.1.4.1.2636.3.60.1.1.1.1.20';
my $ifTable_Low_rx_warn = '.1.3.6.1.4.1.2636.3.60.1.1.1.1.12';

my $ifTable_High_tx_alarm = '.1.3.6.1.4.1.2636.3.60.1.1.1.1.17';
my $ifTable_High_rx_alarm = '.1.3.6.1.4.1.2636.3.60.1.1.1.1.9';
my $ifTable_Low_tx_alarm = '.1.3.6.1.4.1.2636.3.60.1.1.1.1.18';
my $ifTable_Low_rx_alarm = '.1.3.6.1.4.1.2636.3.60.1.1.1.1.10';


my $ifTable_Value_rx = '.1.3.6.1.4.1.2636.3.60.1.1.1.1.5';
my $ifTable_Value_tx = '.1.3.6.1.4.1.2636.3.60.1.1.1.1.7';

my $ifAdminStatus = '.1.3.6.1.2.1.2.2.1.7';


#printf("\n== SNMPv2c blocking get_table(): %s ==\n\n", $ifTable);

my $result;
my @oid;
my @descripcion;

my $i;
$i=0;
if (defined($result = $session->get_table(-baseoid => $ifTable_Descr))) {
   foreach (oid_lex_sort(keys(%{$result}))) {
    if($result->{$_} =~ qr/^(?=.*xe|ge)^[^.]*$/){
      $oid[$i][0]=substr($_,21,length($_));
      $oid[$i][1]=$result->{$_};
#      printf("%s => %s\n", substr($_,21,length($_)), $result->{$_});

      $i++; 
    }
   }
$largo=$i;
} else {
   printf("ERROR: %s.\n\n", $session->error());
}

$i=0;
if (defined($result = $session->get_table(-baseoid => $ifTable_Value_rx))) {
   foreach (oid_lex_sort(keys(%{$result}))) {
     for ($i=0; $i <= $largo; $i++) {
      if($_ eq $ifTable_Value_rx.".".$oid[$i][0]){
               $oid[$i][2]=$result->{$_}/100;
			}}
#            printf("%s => %s\n", $_, $result->{$_});
	}
} else {
   printf("ERROR: %s.\n\n", $session->error());
}
$i=0;
if (defined($result = $session->get_table(-baseoid => $ifTable_Value_tx))) {
   foreach (oid_lex_sort(keys(%{$result}))) {
     for ($i=0; $i <= $largo; $i++) {
      if($_ eq $ifTable_Value_tx.".".$oid[$i][0]){
               $oid[$i][3]=$result->{$_}/100;
                        }}
#            printf("%s => %s\n", $_, $result->{$_});
        }
} else {
   printf("ERROR: %s.\n\n", $session->error());
}

$i=0;
if (defined($result = $session->get_table(-baseoid => $ifAdminStatus))) {
   foreach (oid_lex_sort(keys(%{$result}))) {
     for ($i=0; $i <= $largo; $i++) {
      if($_ eq $ifAdminStatus.".".$oid[$i][0]){
               $oid[$i][99]=$result->{$_};
                        }}
#            printf("%s => %s\n", $_, $result->{$_});
        }
} else {
   printf("ERROR: %s.\n\n", $session->error());
}


$i=0;
if (defined($result = $session->get_table(-baseoid => $ifTable_High_rx_warn))) {
   foreach (oid_lex_sort(keys(%{$result}))) {
     for ($i=0; $i <= $largo; $i++) {
      if($_ eq $ifTable_High_rx_warn.".".$oid[$i][0]){
               $oid[$i][4]=$result->{$_}/100;
			}
			}
#            printf("%s => %s\n", $_, $result->{$_});
	}
} else {
   printf("ERROR: %s.\n\n", $session->error());
}

$i=0;
if (defined($result = $session->get_table(-baseoid => $ifTable_High_tx_warn))) {
   foreach (oid_lex_sort(keys(%{$result}))) {
     for ($i=0; $i <= $largo; $i++) {
      if($_ eq $ifTable_High_tx_warn.".".$oid[$i][0]){
               $oid[$i][6]=$result->{$_}/100;
                        }
                        } 
           # printf("%s => %s\n", $_, $result->{$_});
        }
} else {
   printf("ERROR: %s.\n\n", $session->error());
}

$i=0;
if (defined($result = $session->get_table(-baseoid => $ifTable_High_rx_alarm))) {
   foreach (oid_lex_sort(keys(%{$result}))) {
     for ($i=0; $i <= $largo; $i++) {
      if($_ eq $ifTable_High_rx_alarm.".".$oid[$i][0]){
               $oid[$i][5]=$result->{$_}/100;
                        }
                        }
#            printf("%s => %s\n", $_, $result->{$_});
        }
} else {
   printf("ERROR: %s.\n\n", $session->error());
}

$i=0;
if (defined($result = $session->get_table(-baseoid => $ifTable_High_tx_alarm))) {
   foreach (oid_lex_sort(keys(%{$result}))) {
     for ($i=0; $i <= $largo; $i++) {
      if($_ eq $ifTable_High_tx_alarm.".".$oid[$i][0]){
               $oid[$i][7]=$result->{$_}/100;
                        }
                        } 
           # printf("%s => %s\n", $_, $result->{$_});
        }
} else {
   printf("ERROR: %s.\n\n", $session->error());
}


$i=0;
if (defined($result = $session->get_table(-baseoid => $ifTable_Low_rx_warn))) {
   foreach (oid_lex_sort(keys(%{$result}))) {
     for ($i=0; $i <= $largo; $i++) {
      if($_ eq $ifTable_Low_rx_warn.".".$oid[$i][0]){
               $oid[$i][8]=$result->{$_}/100;
			}
			}
           # printf("%s => %s\n", $_, $result->{$_});
	}
} else {
   printf("ERROR: %s.\n\n", $session->error());
}

$i=0;
if (defined($result = $session->get_table(-baseoid => $ifTable_Low_tx_warn))) {
   foreach (oid_lex_sort(keys(%{$result}))) {
     for ($i=0; $i <= $largo; $i++) {
      if($_ eq $ifTable_Low_tx_warn.".".$oid[$i][0]){
               $oid[$i][10]=$result->{$_}/100;
                        }
                        }
           # printf("%s => %s\n", $_, $result->{$_});
        }
} else {
   printf("ERROR: %s.\n\n", $session->error());
}

$i=0;
if (defined($result = $session->get_table(-baseoid => $ifTable_Low_rx_alarm))) {
   foreach (oid_lex_sort(keys(%{$result}))) {
     for ($i=0; $i <= $largo; $i++) {
      if($_ eq $ifTable_Low_rx_alarm.".".$oid[$i][0]){
               $oid[$i][9]=$result->{$_}/100;
                        }
                        }
           # printf("%s => %s\n", $_, $result->{$_});
        }
} else {
   printf("ERROR: %s.\n\n", $session->error());
}

$i=0;
if (defined($result = $session->get_table(-baseoid => $ifTable_Low_tx_alarm))) {
   foreach (oid_lex_sort(keys(%{$result}))) {
     for ($i=0; $i <= $largo; $i++) {
      if($_ eq $ifTable_Low_tx_alarm.".".$oid[$i][0]){
               $oid[$i][11]=$result->{$_}/100;
                        }
                        }
           # printf("%s => %s\n", $_, $result->{$_});
        }
} else {
   printf("ERROR: %s.\n\n", $session->error());
}





$session->close;
for ($i=0; $i < $largo; $i++) {

    if        (($oid[$i][2]>= $oid[$i][8])&&($oid[$i][2]<= $oid[$i][4])&&($oid[$i][3]>= $oid[$i][10])&&($oid[$i][3]<= $oid[$i][6])){

#	$TEXTO_SALIDA=$TEXTO_SALIDA.$oid[$i][1]." NORMAL ".$oid[$i][2]." ".$UNIDAD." RX ".$oid[$i][3]." ".$UNIDAD." TX ".$oid[$i][4]." ".$oid[$i][6]." ".$oid[$i][8]." ".$oid[$i][10]." \n";	
        $TEXTO_SALIDA=$TEXTO_SALIDA.$oid[$i][1]." NORMAL RX: ".$oid[$i][2]." ".$UNIDAD." TX: ".$oid[$i][3]." ".$UNIDAD." \n";
	} 

        elsif (($oid[$i][99]>="2")){
#        $TEXTO_SALIDA=$TEXTO_SALIDA.$oid[$i][1]." NORMAL ".$oid[$i][2]." ".$UNIDAD." RX ".$oid[$i][3]." ".$UNIDAD." TX ".$oid[$i][4]." ".$oid[$i][6]." ".$oid[$i][8]." ".$oid[$i][10]." \n";
        $TEXTO_SALIDA=$TEXTO_SALIDA.$oid[$i][1]." NORMAL RX: ".$oid[$i][2]." ".$UNIDAD." TX: ".$oid[$i][3]." ".$UNIDAD." \n";
        }
  
        elsif (($oid[$i][2]>= $oid[$i][4])&&($oid[$i][2]<= $oid[$i][5])||($oid[$i][3]>= $oid[$i][6])&&($oid[$i][3]<= $oid[$i][7])){
        if($SALIDA!=2){$SALIDA=1;}  
        $TEXTO_SALIDA=$TEXTO_SALIDA.$oid[$i][1]." WARNING RX: ".$oid[$i][2]." ".$UNIDAD." TX: ".$oid[$i][3]." ".$UNIDAD." WARNING\n";
        }
        elsif (($oid[$i][2]>= $oid[$i][8])&&($oid[$i][2]<= $oid[$i][9])||($oid[$i][3]>= $oid[$i][10])&&($oid[$i][3]<= $oid[$i][11])){
        if($SALIDA!=2){$SALIDA=1;}
        $TEXTO_SALIDA=$TEXTO_SALIDA.$oid[$i][1]." WARNING RX: ".$oid[$i][2]." ".$UNIDAD." TX: ".$oid[$i][3]." ".$UNIDAD." WARNING\n";
        }

 #       elsif (($oid[$i][99]>="2")){
 #       $TEXTO_SALIDA=$TEXTO_SALIDA.$oid[$i][1]." ".$oid[$i][2]." ".$UNIDAD." RX ".$oid[$i][3]." ".$UNIDAD." TX NORMAL ".$oid[$i][4]." ".$oid[$i][6]." ".$oid[$i][8]." ".$oid[$i][10]." \n";
 #       }

	else {
	$SALIDA=2;
	$TEXTO_SALIDA=$TEXTO_SALIDA.$oid[$i][1]." CRITICAL RX: ".$oid[$i][2]." ".$UNIDAD." TX: ".$oid[$i][3]." ".$UNIDAD." CRITICAL\n";
	}
	
}
if ($SALIDA==0){$TEXTO_SALIDA="OK - ".$TEXTO_SALIDA;}
#if ($SALIDA==0){$TEXTO_SALIDA=$TEXTO_SALIDA."all OK\n";}
elsif ($SALIDA==1){$TEXTO_SALIDA="WARNING - ".$TEXTO_SALIDA;}
else {$TEXTO_SALIDA="CRITICAL - ".$TEXTO_SALIDA;}
print $TEXTO_SALIDA;
#dump (@oid);
exit($SALIDA);

sub imprime_ayuda {
    my $exit_status = shift;
 
    print <<"END"
 
    Use: check_sfp_cisco.pl [arguments]
 
    SNMPv2c Request 
 
          --hostname   : switch IP
          --community    : SNMPv2c community name (default public)
          --type     : Type sensor
				power: FC Receive Power Sensor
					FC Transmit Power Sensor
				temp: Temperature Sensor
				bias: Bias Current Sensor
				supply: Supply Power Sensor
          --help     : imprime esta ayuda (opcional)
 
END
;
    exit $exit_status;
}
