function [vn,fn] = mobbcc_climb_with_Bt_varying(fseg,rn,links,connectivity,nodelist,conlist, mobility,dopartials,stackforcevec,rntol,doSFT,SFT_plane,doinclusion,inclusion_pos_rad,dt,Bt_edge,Bt_screw)
%mobility law function (model: BCC0)

%Drag (Mobility) parameters
% Bscrew=1e0;
% Bedge=1e0;
% Beclimb=1e8;

%Bscrew=1.9e-24; % Olmstead
Bedge=3.65e-24; % Olmstead
Bscrew=2e-24;
%Bedge=6e-24;
Beclimb=8e-20;%CAMERON'S TEST
%Beclimb=8e-13;%CAMERON'S TEST


% Alan's modification, introducing Bt dependency on Temperature

Bedge = Bt_edge;  %N/A^2*s
Bscrew = Bt_screw;  %N/A^2*s
Beclimb = Bt_edge*10000;  % make Bt for climb very big to supprese climb from happening

Bline=1.0e-2*min(Bscrew,Bedge);

%numerical tolerance
eps=1e-12;

% length of the nodelist for which the velocity will be calculated
L1=size(nodelist,1);
% if no nodelist is given then the nodelist becomes the whole node population
% this portion of the code sets up that nodelist along with the connlist
% that contains all of the nodal connections
if L1==0
    L1=size(rn,1);
    nodelist=linspace(1,L1,L1)';
    [L2,L3]=size(connectivity);
    conlist=zeros(L2,(L3-1)/2+1);
    conlist(:,1)=connectivity(:,1);
    for i=1:L2
        connumb=conlist(i,1);
        conlist(i,2:connumb+1)=linspace(1,connumb,connumb);
    end
end
% now cycle through all of the nodes for which the velocity must be calculated

for n=1:L1
    n0=nodelist(n);                 %n0 is the nodeid of the nth node in nodelist
    if(doinclusion)
        for k=1:size(inclusion_pos_rad,1)
            if(norm(rn(n0,1:3)-inclusion_pos_rad(k,1:3))<inclusion_pos_rad(k,4))
                Bscrew=1;
                Bedge=Bscrew;%1000*3.0214e-25;
                Bline=1.0e-2*min(Bscrew,Bedge);
            else
%                 Bscrew=1.9e-24; % Olmstead
%                 Bedge=3.65e-24; % Olmstead
%                 Bline=1.0e-0*min(Bscrew,Bedge);
                Bscrew=Bt_screw; % Alan
                Bedge=Bt_edge; % Alan
                Bline=1.0e-0*min(Bscrew,Bedge);
            end
        end
    end
    numNbrs=conlist(n,1);           %numNbrs is the number of connections for node n0 in conlist
    fn(n,:)=zeros(1,3);             % initialize the total force and the total drag matrix
    Btotal=zeros(3,3);
    for i=1:numNbrs
        ii=conlist(n,i+1);                                                                      % connectionid for this connection
        linkid=connectivity(n0,2*ii);
        posinlink=connectivity(n0,2*ii+1);    % can only be '1' or '2'
        n1=links(linkid,3-posinlink);
        rt=rn(n1,1:3)-rn(n0,1:3);                                                               % calculate the length of the link and its tangent line direction
        L=norm(rt);
        if L>0.0
            fsegn0=fseg(linkid,3*(posinlink-1)+[1:3]);  % choosing the first fseg or the second and add it into fn(n,:)
            fn(n,:)=fn(n,:)+fsegn0; % nodeid for the node that n0 is connected to
            burgv=links(connectivity(n0,2*ii),3:5); % burgers vector of the link                                                           
            linedir=rt./L;

            % calculate friction coefficient
            if abs(burgv(1)*burgv(2)*burgv(3))<eps
                Btotal=Btotal+(2.0*L).*((Beclimb).*eye(3)+(Bline-Beclimb).*(linedir'*linedir));
            else
                cth2=(linedir*burgv')^2/(burgv*burgv');                                                 % calculate how close to screw the link is
                Btotal=Btotal+(2.0*L).*((Bscrew).*eye(3)+(Bline-Bscrew).*(linedir'*linedir));           % build the drag matrix assuming that the dislocation is screw type
                if ( 1 - cth2 ) >eps
                    ndir=cross(burgv,linedir)./sqrt((burgv*burgv')*(1-cth2));                           % correct the drag matrix for dislocations that are not screw type
                    mdir=cross(ndir,linedir);
                    Bglide=1 / sqrt( 1 / Bedge^2 + ( 1 / Bscrew^2 - 1 / Bedge^2 ) * cth2);
                    Bclimb=sqrt( Beclimb^2 + ( Bscrew^2 - Beclimb^2 ) * cth2);
                    Btotal=Btotal+(2.0*L).*(( Bglide - Bscrew ).* ( mdir' * mdir ) + ( Bclimb - Bscrew ) .* ( ndir' * ndir ) );
                end
            end
        end
    end
    if rcond(Btotal)<eps
        
        [evec,eval]=eig(Btotal);                    % find eigenvalues and eigen vectors of drag matrix
        evalmax=eval(1,1);
        eval=eval./evalmax;
        fvec=fn(n,:)'./evalmax;
        for i=2:3                                   % invert drag matrix and keep zero eigen values as zero
            if eval(i,i)>eps
                eval(i,i)=1/eval(i,i);
            else
                eval(i,i)=0.0d0;
            end
        end
        vn(n,:)=(evec*eval*evec'*fvec)';  % calculate the velocity 
    else
        vn(n,:)=(Btotal\fn(n,:)')';   % vn:[A/s] fn:[N] Btotal:[%N/A^2*s*A]              % Btotal was wellconditioned so just take the inverse
    end

    
%    if numNbrs==2
%        ii=conlist(n,2);                                                                      
%        n1=links(connectivity(n0,2*ii),3-connectivity(n0,2*ii+1));
%        ii=conlist(n,3);                                                                      
%        n2=links(connectivity(n0,2*ii),3-connectivity(n0,2*ii+1));
%        rt=rn(n1,1:3)-rn(n2,1:3);
%        L=norm(rt);
%        linedir=rt./L;
%        vn(n,:)=((eye(3)-linedir'*linedir)*vn(n,:)')';
%    end

end