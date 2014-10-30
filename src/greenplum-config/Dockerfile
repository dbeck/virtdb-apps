FROM centos:centos6

RUN mkdir /home/testuser
RUN curl http://nodejs.org/dist/v0.10.32/node-v0.10.32.tar.gz > /home/testuser/node-v0.10.32.tar.gz

RUN yum -y groupinstall 'Development Tools'
RUN yum -y install tar

WORKDIR /home/testuser

RUN mkdir node
RUN tar -xzvf node-v0.10.32.tar.gz
WORKDIR node-v0.10.32
RUN ./configure --prefix=/home/testuser/node
RUN make
RUN make install

ENV HOME /home/testuser
ENV PATH /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/testuser/node/bin:/home/testuser/node-v0.10.32/tools/gyp
ENV LD_LIBRARY_PATH /package/lib:/usr/local/lib

RUN curl http://download.opensuse.org/repositories/home:/fengshuo:/zeromq/CentOS_CentOS-6/home:fengshuo:zeromq.repo > /etc/yum.repos.d/zeromq.repo
RUN yum install -y zeromq-devel
RUN yum install -y which

WORKDIR /home/testuser
RUN curl https://protobuf.googlecode.com/svn/rc/protobuf-2.6.0.tar.gz > protobuf-2.6.0.tar.gz
RUN tar -xzvf protobuf-2.6.0.tar.gz
WORKDIR /home/testuser/protobuf-2.6.0
RUN ./configure
RUN make
RUN make install
ENV PKG_CONFIG_PATH /usr/local/lib/pkgconfig

RUN curl http://people.centos.org/tru/devtools-2/devtools-2.repo > /etc/yum.repos.d/devtools-2.repo
RUN yum install -y devtoolset-2-gcc devtoolset-2-binutils
RUN yum install -y devtoolset-2-gcc-c++
ENV PATH /opt/rh/devtoolset-2/root/usr/bin/:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/testuser/node/bin:/home/testuser/node-v0.10.32/tools/gyp

RUN mkdir /package
WORKDIR /package
