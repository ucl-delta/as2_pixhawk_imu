#########################################################################################
# Micro XRCE-DDS Docker
# https://github.com/eProsima/Micro-XRCE-DDS
#########################################################################################

# Build stage
FROM ubuntu AS build
ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /root

# Essentials
RUN apt-get update
RUN apt-get install -y \
            software-properties-common \
            build-essential \
            cmake \
            git

# Java
RUN apt install -y openjdk-8-jdk
ENV JAVA_HOME "/usr/lib/jvm/java-8-openjdk-amd64/"

# Gradle
RUN apt-get install -y gradle

RUN apt-get clean

# Prepare Micro XRCE-DDS workspace
RUN git clone https://github.com/eProsima/Micro-XRCE-DDS.git -b v2.4.3 /uxrce

# Build Micro XRCE-DDS and install
RUN mkdir -p /uxrce/build && cd /uxrce/build && \
    cmake \
        -DCMAKE_INSTALL_PREFIX=../install \
        -DUXRCE_BUILD_EXAMPLES=ON \
        -DUXRCE_BUILD_AGENT_EXECUTABLE=ON \
        .. &&\
    make -j $(nproc) && make install

# Prepare Micro XRCE-DDS artifacts
RUN cd /uxrce && \
    tar -czvf install.tar.gz  -C install .

#########################################################################################
# Stage 2, Install MicroXRCE and Build & Install Aerostack2
# https://github.com/aerostack2/aerostack2/blob/main/docker/humble/Dockerfile
#########################################################################################

FROM ros:humble-ros-core

WORKDIR /root

###### Copy Micro XRCE-DDS build artifacts
COPY --from=build /uxrce/install.tar.gz  /usr/local/
RUN tar -xzvf /usr/local/install.tar.gz -C /usr/local/ &&\
    rm /usr/local/install.tar.gz

RUN apt update \
    &&  apt install -y wget \
    &&  rm -rf /var/lib/apt/lists/*
RUN wget https://raw.githubusercontent.com/eProsima/Micro-XRCE-DDS-Agent/master/agent.refs
RUN ldconfig

######### Install Aerostack2
WORKDIR /root/
RUN apt-get update -y \
    && apt-get install -y \
        apt-utils \
        software-properties-common \
        git \
        tmux \
        tmuxinator \
        python3-rosdep  \
        python3-pip     \
        python3-colcon-common-extensions \
        python3-colcon-mixin \
        ros-dev-tools \
        python3-flake8 \
        python3-flake8-builtins  \
        python3-flake8-comprehensions \
        python3-flake8-docstrings \
        python3-flake8-import-order \
        python3-flake8-quotes \
        cppcheck lcov \
    &&  rm -rf /var/lib/apt/lists/*

RUN pip3 install pylint flake8==4.0.1 pycodestyle==2.8 cmakelint cpplint  colcon-lcov-result PySimpleGUI-4-foss

# RUN colcon mixin update default
# RUN rm -rf log # remove log folder

RUN mkdir -p /root/aerostack2_ws/src/
WORKDIR /root/aerostack2_ws/src/
RUN git clone https://github.com/aerostack2/aerostack2.git aerostack2 -b main --depth=1
RUN git clone https://github.com/aerostack2/as2_platform_pixhawk.git as2_platform_pixhawk -b main --depth=1
RUN git clone https://github.com/PX4/px4_msgs.git px4_msgs -b release/1.14 --depth=1

# Cut down set of deps from rosdep
RUN apt-get update -y\
    && apt-get install -y \
        ros-humble-tf2 \
        ros-humble-tf2-ros \
        ros-humble-sdformat-urdf \
        ros-humble-robot-state-publisher \
        ros-humble-image-transport \
        ros-humble-tf2-msgs \
        ros-humble-cv-bridge \
        python3-jinja2 \
        python3-pydantic \
        libeigen3-dev \
        libyaml-cpp-dev \
        libbenchmark-dev \
        ros-humble-tf2-geometry-msgs \
        ros-humble-geographic-msgs \
        ros-humble-mocap4r2-msgs \
        python3-pymap3d \
        libgeographic-dev \
        pybind11-dev \
        libncurses-dev \
    # && rosdep init && rosdep update \
    # && rosdep fix-permissions \
    # && rosdep install --from-paths src --ignore-src -r -y \
    &&  rm -rf /var/lib/apt/lists/*

WORKDIR /root/aerostack2_ws
RUN . /opt/ros/$ROS_DISTRO/setup.sh \
    && colcon build --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=Release \
        --packages-select \
            as2_core \ 
            as2_msgs \
            as2_state_estimator \
            px4_msgs \
            as2_platform_pixhawk \
            as2_alphanumeric_viewer \        
    && echo "source /opt/ros/$ROS_DISTRO/setup.bash" >> ~/.bashrc \
    && echo 'export AEROSTACK2_PATH=/root/aerostack2_ws/src/aerostack2' >> ~/.bashrc \
    && echo 'source $AEROSTACK2_PATH/as2_cli/setup_env.bash' >> ~/.bashrc

WORKDIR /root/aerostack2_ws/src/
ADD . as2_pixhawk_imu

WORKDIR /root/aerostack2_ws/src/as2_pixhawk_imu
CMD ["./launch_as2.bash", "-x"]

